using Crosspipe;
using PipeWire;

namespace Crosspipe.Backend {

    // Node mode
    public enum NodeMode {
        NONE = 0,
        INPUT = 1,    // Sink - receives data
        OUTPUT = 2,   // Source - produces data
        DUPLEX = 3    // Both input and output
    }
    
    // Node type flags
    [Flags]
    public enum NodeType {
        NONE = 0,
        AUDIO = 1,
        VIDEO = 2,
        MIDI = 4
    }
    
    // Port flags
    [Flags]
    public enum PortFlags {
        NONE = 0,
        PHYSICAL = 1,   // Hardware port
        TERMINAL = 2,   // Terminal port (no internal routing)
        MONITOR = 4,    // Monitor output
        CONTROL = 8     // Control port
    }

    public class PipeWireBackend : Backend {
        
        internal PipeWire.Context? context;
        internal PipeWire.Core? core;
        internal PipeWire.Registry? registry;
        internal PipeWire.ThreadLoop? loop;
        internal unowned PipeWire.Loop? pw_loop;
        
        private bool is_connected = false;
        private SPA.Hook registry_listener = SPA.Hook();
        private SPA.Hook core_listener = SPA.Hook();
        private GPW.RegistryEvents registry_events;
        private GPW.CoreEvents core_events;
        
        // Sync state
        internal int pending_seq = 0;
        internal int last_seq = 0;
        internal int last_res = 0;
        internal bool has_error = false;

        // Maps for tracking objects
        internal Gee.HashMap<uint, NodeInfo> nodes_map = new Gee.HashMap<uint, NodeInfo>();
        internal Gee.HashMap<uint, PortInfo> ports_map = new Gee.HashMap<uint, PortInfo>();
        internal Gee.HashMap<uint, LinkInfo> links_map = new Gee.HashMap<uint, LinkInfo>();
        
        // Initialization state
        internal bool initial_scan_done = false;
        internal int init_seq = -1;

        public override bool connected { get { return is_connected; } }

        // Extended NodeInfo
        internal class NodeInfo {
            public uint id;
            public string name;           // Full name (may include app_name/)
            public string nick;           // Short nick for display
            public NodeMode mode;         // Input/Output/Duplex
            public NodeType node_type;    // Audio/Video/MIDI flags
            public string? media_class;   // Original media.class string
            public bool is_sink;          // Legacy compatibility
            public bool visible;          // Whether node has been shown (has ports)
            
            public NodeInfo (uint id, string name, string nick, NodeMode mode, NodeType node_type, string? media_class) {
                this.id = id;
                this.name = name;
                this.nick = nick;
                this.mode = mode;
                this.node_type = node_type;
                this.media_class = media_class;
                this.is_sink = (mode == NodeMode.INPUT);
                this.visible = false;
            }
        }
        
        // Extended PortInfo
        internal class PortInfo {
            public uint id;
            public uint node_id;
            public string name;
            public bool is_input;
            public Canvas.PortType port_type;
            public PortFlags flags;
            
            public PortInfo (uint id, uint node_id, string name, bool is_input, 
                            Canvas.PortType port_type, PortFlags flags = PortFlags.NONE) {
                this.id = id;
                this.node_id = node_id;
                this.name = name;
                this.is_input = is_input;
                this.port_type = port_type;
                this.flags = flags;
            }
        }

        internal class LinkInfo {
            public uint id;
            public uint output_port_id;
            public uint input_port_id;
            
            public LinkInfo (uint id, uint output_port_id, uint input_port_id) {
                this.id = id;
                this.output_port_id = output_port_id;
                this.input_port_id = input_port_id;
            }
        }
        
        // Start backend
        public override void start () throws Error {
            PipeWire.init (null, null);

            loop = new PipeWire.ThreadLoop ("crosspipe-loop", null);
            if (loop == null) throw new BackendError.CREATE_FAILED ("Failed to create thread loop");

            pw_loop = loop.get_loop();
            
            context = new PipeWire.Context (loop.get_loop(), null, 0);
            if (context == null) throw new BackendError.CREATE_FAILED ("Failed to create context");
            
            if (loop.start () < 0) {
                 throw new BackendError.CREATE_FAILED ("Failed to start thread loop");
            }
            
            loop.lock();
            
            try {
                core = context.connect (null, 0);
                if (core == null) {
                    loop.unlock();
                    throw new BackendError.NOT_CONNECTED ("Failed to connect core");
                }
                
                // Add core listener
                core_events = GPW.CoreEvents();
                core_events.version = PipeWire.VERSION_CORE_EVENTS;
                core_events.done = on_core_done;
                core_events.error = on_core_error;
                
                GPW.core_add_listener(core, ref core_listener, ref core_events, this);

                registry = core.get_registry (PipeWire.VERSION_REGISTRY_EVENTS, 0);
                
                // Add registry listener
                registry_events = GPW.RegistryEvents();
                registry_events.version = PipeWire.VERSION_REGISTRY_EVENTS;
                registry_events.global = on_global;
                registry_events.global_remove = on_global_remove;
                
                GPW.registry_add_listener(registry, ref registry_listener, ref registry_events, this);
                
                // Request sync to determine when initial object scan is complete
                init_seq = core.sync(0, 0);
                initial_scan_done = false;

                sync_core();
                is_connected = true;
                print("PipeWireBackend: Connected to PipeWire\n");
                
            } catch (Error e) {
                loop.unlock();
                stop_internal (true);  // Skip lock since we already unlocked
                throw e;
            }
            
            loop.unlock();
        }

        public override void stop () {
            stop_internal (false);
        }

        private void stop_internal (bool already_unlocked) {
            bool locked = false;
            if (loop != null && !already_unlocked) {
                loop.lock();
                locked = true;
            }
            
            nodes_map.clear();
            ports_map.clear();
            links_map.clear();
            
            if (registry != null) {
                 registry = null;
            }
            if (core != null) {
                core = null;
            }
            if (context != null) {
                context = null;
            }
            
            if (loop != null) {
                if (locked) loop.unlock();
                loop.stop();
                loop = null;
            }
            
            is_connected = false;
        }

        // Create link
        public override void create_link (uint output_port_id, uint input_port_id) throws Error {
            if (!is_connected || registry == null || core == null || loop == null) {
                throw new BackendError.NOT_CONNECTED ("Not connected to PipeWire");
            }
            
            var out_port = ports_map.get(output_port_id);
            var in_port = ports_map.get(input_port_id);
            
            if (out_port == null || in_port == null) {
                throw new BackendError.PORT_NOT_FOUND ("Port not found");
            }
            
            if (out_port.is_input || !in_port.is_input) {
                throw new BackendError.INVALID_DIRECTION ("Invalid port direction");
            }
            
            loop.lock();
            
            int result = GPW.create_link(
                core,
                out_port.node_id,
                output_port_id,
                in_port.node_id,
                input_port_id
            );
            
            // Sync to ensure the link is created
            sync_core();
            
            loop.unlock();
            
            if (result < 0) {
                throw new BackendError.CREATE_FAILED ("Failed to create link: %d".printf(result));
            }
            
            debug("Created link: %u -> %u", output_port_id, input_port_id);
        }


        // Destroy link
        public override void destroy_link (uint link_id) throws Error {
            if (!is_connected || registry == null || loop == null) {
                throw new BackendError.NOT_CONNECTED ("Not connected to PipeWire");
            }
            
            if (!links_map.has_key(link_id)) {
                throw new BackendError.LINK_NOT_FOUND ("Link not found: %u".printf(link_id));
            }
            
            loop.lock();
            
            int result = registry.destroy(link_id);
            
            // Sync to wait for completion
            sync_core();
            
            loop.unlock();
            
            if (result < 0) {
                throw new BackendError.DESTROY_FAILED ("Failed to destroy link: %d".printf(result));
            }
            
            debug("Destroyed link: %u", link_id);
        }

        public override void destroy_link_by_ports (uint output_port_id, uint input_port_id) throws Error {
            uint? found_link_id = null;
            
            foreach (var entry in links_map.entries) {
                var link = entry.value;
                if (link.output_port_id == output_port_id && link.input_port_id == input_port_id) {
                    found_link_id = link.id;
                    break;
                }
            }
            
            if (found_link_id == null) {
                throw new BackendError.LINK_NOT_FOUND ("Link not found for ports: %u -> %u".printf(output_port_id, input_port_id));
            }
            
            destroy_link(found_link_id);
        }
        
        // Re-emit known objects
        public override void refresh () {
            // Re-emit signals for all known and visible objects to rebuild the view
            foreach (var node in nodes_map.values) {
                if (node.visible) {
                    node_added (node.id, node.name, node.nick, node.mode, node.node_type);
                }
            }
            
            foreach (var port in ports_map.values) {
                // Ensure parent node is visible before emitting port
                var node = nodes_map.get(port.node_id);
                if (node != null && node.visible) {
                    port_added (port.node_id, port.id, port.name, port.is_input, port.port_type, port.flags);
                }
            }
            
            foreach (var link in links_map.values) {
                link_added (link.id, link.output_port_id, link.input_port_id);
            }
            
            refreshed ();
        }
        
        // Sync core
        internal void sync_core () {
            print("PipeWireBackend: Sync core start pending=%d\n", pending_seq);
            if (loop == null || core == null) return;
            
            if (loop.in_thread()) return;
            
            pending_seq = core.sync(PipeWire.ID_CORE, pending_seq);
            
            while (true) {
                loop.wait();
                if (has_error) break;
                if (pending_seq == last_seq) break;
            }
        }
    }

    // Parse boolean property
    internal static bool parse_bool (string? val) {
        if (val == null) return false;
        return val == "true" || val == "1";
    }
    
    // Core done event handler
    internal static void on_core_done (void* data, uint32 id, int seq) {
        var self = (PipeWireBackend)data;
        print("PipeWireBackend: Core done seq=%d\n", seq);
        
        if (id == PipeWire.ID_CORE) {
            self.last_seq = seq;
            if (seq == self.init_seq) {
                if (!self.initial_scan_done) {
                    self.initial_scan_done = true;
                    // Trigger refresh on main thread to sort and display everything
                    Idle.add(() => {
                        self.refresh();
                        return false;
                    });
                }
            }
            if (self.pending_seq == seq && self.loop != null) {
                self.loop.signal(false);
            }
        }
    }
    
    internal static void on_core_error (void* data, uint32 id, int seq, int res, string message) {
        var self = (PipeWireBackend)data;
        print("PipeWireBackend: Core error: id=%u seq=%d res=%d msg=%s\n", id, seq, res, message);
        
        warning("PipeWire core error: id=%u seq=%d res=%d: %s", id, seq, res, message);
        
        if (id == PipeWire.ID_CORE) {
            self.last_res = res;
            if (res == -32) { // EPIPE
                self.has_error = true;
            }
        }
        
        if (self.loop != null) {
            self.loop.signal(false);
        }
    }

    // Registry global event handler
    internal static void on_global (void *data, uint32 id, uint32 _permissions, string type, uint32 _version, SPA.Dict? props) {
        var self = (PipeWireBackend)data;
        print("PipeWireBackend: Global added: id=%u type=%s\n", id, type);
        
        string? name = null;
        if (props != null) {
            name = props.get(PipeWire.KEY_NODE_NAME);
            if (name == null) name = props.get(PipeWire.KEY_NODE_NICK);
            if (name == null) name = props.get(PipeWire.KEY_NODE_DESCRIPTION);
        }
        if (type == PipeWire.Node.INTERFACE_NAME) {
            print("PipeWireBackend: Node global id=%u\n", id); 
            // Parse node name following qpwgraph pattern:
            string? node_desc = null;
            string? node_nick = null;
            string? app_name = null;
            string? media_class = null;
            
            if (props != null) {
                node_desc = props.get(PipeWire.KEY_NODE_DESCRIPTION);
                node_nick = props.get(PipeWire.KEY_NODE_NICK);
                
                if (node_desc == null || node_desc.length == 0) {
                    node_desc = node_nick;
                }
                if (node_desc == null || node_desc.length == 0) {
                    node_desc = props.get(PipeWire.KEY_NODE_NAME);
                }
                
                app_name = props.get(PipeWire.KEY_APP_NAME);
                media_class = props.get(PipeWire.KEY_MEDIA_CLASS);
            }
            
            if (node_desc == null || node_desc.length == 0) {
                node_desc = "node";
            }
            
            // Build full node name: app_name/node_description (if different)
            string node_name = node_desc;
            if (app_name != null && app_name.length > 0 && app_name != node_desc) {
                node_name = app_name + "/" + node_desc;
            }
            
            // Use nick for display, fallback to description
            string nick = node_nick ?? node_desc;
            
            // Determine node mode from media.class
            NodeMode node_mode = NodeMode.NONE;
            NodeType node_type = NodeType.NONE;
            
            if (media_class != null) {
                // Mode: Source/Output = OUTPUT, Sink/Input = INPUT
                if (media_class.contains("Source") || media_class.contains("Output")) {
                    node_mode = NodeMode.OUTPUT;
                } else if (media_class.contains("Sink") || media_class.contains("Input")) {
                    node_mode = NodeMode.INPUT;
                }
                
                // Check for Duplex via media.category if mode is still NONE
                if (node_mode == NodeMode.NONE) {
                    var media_category = props != null ? props.get("media.category") : null;
                    if (media_category != null && media_category.contains("Duplex")) {
                        node_mode = NodeMode.DUPLEX;
                    }
                }
                
                // Type: Audio/Video/Midi flags
                if (media_class.contains("Audio")) {
                    node_type |= NodeType.AUDIO;
                }
                if (media_class.contains("Video")) {
                    node_type |= NodeType.VIDEO;
                }
                if (media_class.contains("Midi")) {
                    node_type |= NodeType.MIDI;
                }
            }
            
            var node_info = new PipeWireBackend.NodeInfo(id, node_name, nick, node_mode, node_type, media_class);
            self.nodes_map.set(id, node_info);
            
            // Check if ports already exist for this node (unlikely but possible out-of-order)
            bool has_ports = false;
            foreach (var p in self.ports_map.values) {
                if (p.node_id == id) {
                    has_ports = true;
                    break;
                }
            }
            
            if (has_ports) {
                node_info.visible = true;
                if (self.initial_scan_done) {
                    Idle.add (() => {
                         self.node_added (id, node_name, nick, node_mode, node_type); 
                         return false;
                    });
                }
            }
        } 
        else if (type == PipeWire.Port.INTERFACE_NAME) {
            print("PipeWireBackend: Port global id=%u\n", id);
            uint node_id = 0;
            if (props != null) {
                var nid = props.get(PipeWire.KEY_NODE_ID);
                if (nid != null) node_id = (uint)int.parse(nid);
            }
             
            // Get port name from alias or name  
            string port_name = "port";
            if (props != null) {
                var alias = props.get(PipeWire.KEY_PORT_ALIAS);
                if (alias != null) {
                    port_name = alias;
                } else {
                    var pn = props.get(PipeWire.KEY_PORT_NAME);
                    if (pn != null) port_name = pn;
                }
            }
             
            // Determine direction
            bool is_input = false;
            if (props != null) {
                var dir = props.get(PipeWire.KEY_PORT_DIRECTION);
                if (dir == "in") is_input = true;
            }
            
            // Determine port type from format.dsp
            Canvas.PortType ptype = Canvas.PortType.OTHER;
            if (props != null) {
                var format_dsp = props.get(PipeWire.KEY_FORMAT_DSP);
                if (format_dsp != null) {
                    if (format_dsp.contains("audio") || format_dsp.contains("32 bit float mono")) {
                        ptype = Canvas.PortType.AUDIO;
                    } else if (format_dsp.contains("midi") || format_dsp.contains("8 bit raw")) {
                        ptype = Canvas.PortType.MIDI;
                    } else if (format_dsp.contains("video")) {
                        ptype = Canvas.PortType.VIDEO;
                    }
                } else {
                    // Fallback: use parent node's type
                    var node = self.nodes_map.get(node_id);
                    if (node != null) {
                        if ((node.node_type & NodeType.VIDEO) != 0) {
                            ptype = Canvas.PortType.VIDEO;
                        } else if ((node.node_type & NodeType.MIDI) != 0) {
                            ptype = Canvas.PortType.MIDI;
                        } else {
                            ptype = Canvas.PortType.AUDIO;
                        }
                    }
                }
            }
            
            // Parse port flags
            PortFlags pflags = PortFlags.NONE;
            if (props != null) {
                var physical = props.get("port.physical");
                if (physical != null && parse_bool(physical)) {
                    pflags |= PortFlags.PHYSICAL;
                }
                
                var terminal = props.get("port.terminal");
                if (terminal != null && parse_bool(terminal)) {
                    pflags |= PortFlags.TERMINAL;
                }
                
                var monitor = props.get("port.monitor");
                if (monitor != null && parse_bool(monitor)) {
                    pflags |= PortFlags.MONITOR;
                }
                
                var control = props.get("port.control");
                if (control != null && parse_bool(control)) {
                    pflags |= PortFlags.CONTROL;
                }
                
                // Also set TERMINAL if node is not duplex
                var node = self.nodes_map.get(node_id);
                if (node != null && node.mode != NodeMode.DUPLEX) {
                    pflags |= PortFlags.TERMINAL;
                }
            }
            
            self.ports_map.set(id, new PipeWireBackend.PortInfo(id, node_id, port_name, is_input, ptype, pflags));
            
            // If parent node is not yet visible, make it visible now
            var node = self.nodes_map.get(node_id);
            if (node != null && !node.visible) {
                node.visible = true;
                if (self.initial_scan_done) {
                    Idle.add (() => {
                        self.node_added (node.id, node.name, node.nick, node.mode, node.node_type);
                        return false;
                    });
                }
            }
             
            if (self.initial_scan_done) {
                Idle.add (() => {
                    self.port_added (node_id, id, port_name, is_input, ptype, pflags);
                    return false;
                });
            }
        }
        else if (type == PipeWire.Link.INTERFACE_NAME) {
            print("PipeWireBackend: Link global id=%u\n", id);
            uint out_port = 0;
            uint in_port = 0;
            
            if (props != null) {
                var op = props.get(PipeWire.KEY_LINK_OUTPUT_PORT);
                if (op != null) out_port = (uint)int.parse(op);
                var ip = props.get(PipeWire.KEY_LINK_INPUT_PORT);
                if (ip != null) in_port = (uint)int.parse(ip);
            }
            
            self.links_map.set(id, new PipeWireBackend.LinkInfo(id, out_port, in_port));
            
            if (self.initial_scan_done) {
                Idle.add (() => {
                    self.link_added (id, out_port, in_port);
                    return false;
                });
            }
        }
    }
    
    // Registry global_remove callback
    internal static void on_global_remove (void *data, uint32 id) {
        var self = (PipeWireBackend)data;
        print("PipeWireBackend: Global removed: id=%u\n", id);
        
        // Determine which type of object was removed
        if (self.nodes_map.has_key(id)) {
            string? name = "unknown";
            var node = self.nodes_map.get(id);
            if (node != null) name = node.name;
            
            self.nodes_map.unset(id);
            
            if (node != null && node.visible) {
                if (self.initial_scan_done) {
                    Idle.add (() => {
                        self.node_removed (id);
                        return false;
                    });
                }
                debug("Node removed: %u '%s'", id, name);
            }
        } 
        else if (self.ports_map.has_key(id)) {
            var port = self.ports_map.get(id);
            self.ports_map.unset(id);
            if (self.initial_scan_done) {
                Idle.add (() => {
                    if (port != null) self.port_removed (port.node_id, id);
                    return false;
                });
            }
        }
        else if (self.links_map.has_key(id)) {
            var link = self.links_map.get(id);
            uint out_port = link.output_port_id;
            uint in_port = link.input_port_id;
            
            self.links_map.unset(id);
            if (self.initial_scan_done) {
                Idle.add (() => {
                    self.link_removed (id, out_port, in_port);
                    return false;
                });
            }
        }
    }
}
