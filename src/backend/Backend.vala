namespace Crosspipe.Backend {

    public errordomain BackendError {
        NOT_CONNECTED,
        PORT_NOT_FOUND,
        LINK_NOT_FOUND,
        INVALID_DIRECTION,
        CREATE_FAILED,
        DESTROY_FAILED
    }


    // Backend interface
    public abstract class Backend : Object {
        
        // Signals for graph changes
        public signal void node_added (uint id, string name, string nick, NodeMode mode, NodeType node_type);
        public signal void node_removed (uint id);
        public signal void port_added (uint node_id, uint port_id, string name, 
                                       bool is_input, Canvas.PortType port_type, PortFlags flags);
        public signal void port_removed (uint node_id, uint port_id);
        public signal void link_added (uint link_id, uint output_port_id, uint input_port_id);
        public signal void link_removed (uint link_id, uint output_port_id, uint input_port_id);
        
        // Signal emitted when a full refresh is complete (including initial scan)
        public signal void refreshed ();
        
        // Connection state
        public abstract bool connected { get; }
        
        // Methods
        public virtual void start () throws Error {
            throw new BackendError.CREATE_FAILED ("Not implemented");
        }
        
        public virtual void stop () {
            // Virtual no-op
        }
        
        public virtual void create_link (uint output_port_id, uint input_port_id) throws Error {
            throw new BackendError.CREATE_FAILED ("Not implemented: %u -> %u".printf(output_port_id, input_port_id));
        }
        
        public virtual void destroy_link (uint link_id) throws Error {
            throw new BackendError.DESTROY_FAILED ("Not implemented: %u".printf(link_id));
        }
        
        public virtual void destroy_link_by_ports (uint output_port_id, uint input_port_id) throws Error {
            throw new BackendError.DESTROY_FAILED ("Not implemented: %u -> %u".printf(output_port_id, input_port_id));
        }
        
        public virtual void refresh () {
            // Virtual no-op
        }
    }
}
