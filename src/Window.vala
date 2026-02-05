namespace Crosspipe {
    public class Window : Adw.ApplicationWindow {
        private Canvas.GraphCanvas canvas;

        private Backend.PipeWireBackend? backend = null;

        private double _zoom = 1.0;
        public double zoom {
            get { return _zoom; }
            set {
                _zoom = value.clamp (0.1, 4.0);
                canvas.zoom = _zoom;
                zoom_label.label = "%.0f%%".printf (_zoom * 100);
            }
        }
        
        private Gtk.Label zoom_label;

        private SimpleAction undo_action;
        private SimpleAction redo_action;
        
        // Graph updates flag
        private bool ignore_graph_updates = false;

        // Node counters for automatic layout
        private int source_nodes_count = 0;
        private int sink_nodes_count = 0;
        private const int NODES_PER_COLUMN = 8;
        private const double COLUMN_WIDTH = 256.0;
        private const double ROW_HEIGHT = 128.0;
        
        public Window (Gtk.Application app) {
            Object (application: app);
        }
        
        construct {
            // Window properties
            title = Config.APP_NAME;
            default_width = 1200;
            default_height = 800;
            
            // Window actions
            var action_group = new SimpleActionGroup ();
            
            var zoom_in_action = new SimpleAction ("zoom-in", null);
            zoom_in_action.activate.connect ((_action, _parameter) => canvas.zoom *= 1.1);
            action_group.add_action (zoom_in_action);
            
            var zoom_out_action = new SimpleAction ("zoom-out", null);
            zoom_out_action.activate.connect ((_action, _parameter) => canvas.zoom /= 1.1);
            action_group.add_action (zoom_out_action);
            
            var zoom_reset_action = new SimpleAction ("zoom-reset", null);
            zoom_reset_action.activate.connect ((_action, _parameter) => canvas.zoom = 1.0);
            action_group.add_action (zoom_reset_action);
            
            var zoom_fit_action = new SimpleAction ("zoom-fit", null);
            zoom_fit_action.activate.connect ((_action, _parameter) => canvas.fit_to_content ());
            action_group.add_action (zoom_fit_action);
            
            var refresh_action = new SimpleAction ("refresh", null);
            refresh_action.activate.connect ((_action, _parameter) => on_refresh ());
            action_group.add_action (refresh_action);
            
            var disconnect_all_action = new SimpleAction ("disconnect-all", null);
            disconnect_all_action.activate.connect ((_action, _parameter) => on_disconnect_all ());
            action_group.add_action (disconnect_all_action);
            
            var disconnect_selected_action = new SimpleAction ("disconnect-selected", null);
            disconnect_selected_action.activate.connect ((_action, _parameter) => canvas.delete_selected ());
            action_group.add_action (disconnect_selected_action);
            
            var disconnect_node_action = new SimpleAction ("disconnect-node", null);
            disconnect_node_action.activate.connect ((_action, _parameter) => canvas.disconnect_hovered_node ());
            action_group.add_action (disconnect_node_action);
            
            var select_all_action = new SimpleAction ("select-all", null);
            select_all_action.activate.connect ((_action, _parameter) => canvas.select_all ());
            action_group.add_action (select_all_action);
            
            undo_action = new SimpleAction ("undo", null);
            undo_action.activate.connect ((_action, _parameter) => canvas.command_manager.undo ());
            action_group.add_action (undo_action);
 
            redo_action = new SimpleAction ("redo", null);
            redo_action.activate.connect (() => { canvas.command_manager.redo (); });
            action_group.add_action (redo_action);
            
            this.insert_action_group ("win", action_group);

            build_ui ();
            
            init_backend ();
        }
        
        private void build_ui () {
            var header = new Adw.HeaderBar ();
            
            var menu_button = new Gtk.MenuButton () {
                icon_name = "open-menu-symbolic",
                tooltip_text = "Main Menu"
            };
            
            var menu = new Menu ();
            menu.append ("Refresh", "win.refresh");
            menu.append ("Disconnect All", "win.disconnect-all");
            
            var view_section = new Menu ();
            view_section.append ("Zoom In", "win.zoom-in");
            view_section.append ("Zoom Out", "win.zoom-out");
            view_section.append ("Reset Zoom", "win.zoom-reset");
            view_section.append ("Fit to Content", "win.zoom-fit");
            menu.append_section ("View", view_section);
            
            var app_section = new Menu ();
            app_section.append ("Shortcuts", "app.shortcuts");
            app_section.append ("About", "app.about");
            app_section.append ("Quit", "app.quit");
            menu.append_section (null, app_section);
            
            menu_button.menu_model = menu;
            header.pack_end (menu_button);
            
            // Refresh button
            var refresh_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
            refresh_btn.tooltip_text = "Refresh (F5)";
            refresh_btn.action_name = "win.refresh";
            header.pack_end (refresh_btn);
            
            // Zoom controls
            var zoom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            zoom_box.add_css_class ("linked");
            
            var zoom_out_btn = new Gtk.Button.from_icon_name ("zoom-out-symbolic");
            zoom_out_btn.tooltip_text = "Zoom Out (Ctrl+-)";
            zoom_out_btn.action_name = "win.zoom-out";
            
            var zoom_btn = new Gtk.Button ();
            zoom_btn.action_name = "win.zoom-reset";
            zoom_btn.tooltip_text = "Reset Zoom (Ctrl+0)";
            
            zoom_label = new Gtk.Label ("100%");
            zoom_label.width_chars = 4;
            zoom_btn.child = zoom_label;
            
            var zoom_in_btn = new Gtk.Button.from_icon_name ("zoom-in-symbolic");
            zoom_in_btn.tooltip_text = "Zoom In (Ctrl++)";
            zoom_in_btn.action_name = "win.zoom-in";
            
            zoom_box.append (zoom_out_btn);
            zoom_box.append (zoom_btn);
            zoom_box.append (zoom_in_btn);
            
            var zoom_fit_btn = new Gtk.Button.from_icon_name ("zoom-fit-best-symbolic");
            zoom_fit_btn.tooltip_text = "Fit to Content (Ctrl+F)";
            zoom_fit_btn.action_name = "win.zoom-fit";
            zoom_box.append (zoom_fit_btn);
            
            header.pack_start (zoom_box);
            
            // Main content
            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            
            // Canvas overlay
            var overlay = new Gtk.Overlay ();
            
            // Graph canvas
            var scrolled_window = new Gtk.ScrolledWindow ();
            canvas = new Canvas.GraphCanvas ();
            canvas.vexpand = true;
            canvas.hexpand = true;
            scrolled_window.child = canvas;
            overlay.child = scrolled_window;
            
            main_box.append (overlay);
            
            // Info bar at bottom
            var info_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            info_bar.add_css_class ("toolbar");
            info_bar.margin_start = 12;
            info_bar.margin_end = 12;
            info_bar.margin_top = 6;
            info_bar.margin_bottom = 6;
            
            // Undo/Redo info
            var history_label = new Gtk.Label ("");
            history_label.add_css_class ("dim-label");
            info_bar.append (history_label);
            
            var nodes_label = new Gtk.Label ("Nodes: 0");
            nodes_label.add_css_class ("dim-label");
            info_bar.append (nodes_label);
            
            var connections_label = new Gtk.Label ("Connections: 0");
            connections_label.add_css_class ("dim-label");
            info_bar.append (connections_label);
            
            main_box.append (info_bar);
            
            // Toolbarview to combine header + content
            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header);
            toolbar_view.content = main_box;
            
            this.content = toolbar_view;
            
            // Connect canvas signals
            canvas.stats_changed.connect ((_canvas_sender, nodes, connections) => {
                nodes_label.label = "Nodes: %d".printf (nodes);
                connections_label.label = "Connections: %d".printf (connections);
            });
            
            canvas.connection_created.connect (on_canvas_connection_created);
            canvas.connection_removed.connect (on_canvas_connection_removed);

            canvas.command_manager.changed.connect ((_manager_sender) => {
                undo_action.set_enabled (canvas.command_manager.can_undo);
                redo_action.set_enabled (canvas.command_manager.can_redo);
                
                string undo_text = canvas.command_manager.can_undo ? "Undo: " + canvas.command_manager.undo_label : "";
                history_label.label = undo_text;
            });
            
            // Sync zoom label when canvas zoom changes
            canvas.notify["zoom"].connect (() => {
                if (_zoom != canvas.zoom) {
                    _zoom = canvas.zoom;
                    zoom_label.label = "%.0f%%".printf (_zoom * 100);
                }
            });
        }
        
        private void init_backend () {
            try {
                backend = new Backend.PipeWireBackend ();
                backend.node_added.connect ((id, name, nick, mode, node_type) => on_node_added (id, name, nick, mode, node_type));
                backend.node_removed.connect ((id) => on_node_removed (id));
                backend.port_added.connect ((node_id, port_id, name, is_input, port_type, flags) => on_port_added (node_id, port_id, name, is_input, port_type, flags));
                backend.link_added.connect ((link_id, out_port, in_port) => on_link_added (link_id, out_port, in_port));
                backend.link_removed.connect ((link_id, out_port, in_port) => on_link_removed (link_id, out_port, in_port));
                backend.refreshed.connect (() => {
                     // Auto-fit on refresh
                     canvas.fit_to_content ();
                     zoom = canvas.zoom;
                });
                
                // Start real PipeWire backend
                backend.start ();
                
            } catch (Error e) {
                warning ("Failed to initialize PipeWire backend: %s", e.message);
                show_error_dialog ("PipeWire Error", e.message);
            }
        }
        
        private void on_node_added (uint id, string name, string nick, Backend.NodeMode mode, Backend.NodeType _node_type) {
            debug("Window: Node Added signal received: %u '%s' (nick: '%s')", id, name, nick);
            bool is_sink = (mode == Backend.NodeMode.INPUT);
            var node = new Canvas.Node (id, name, is_sink);

            // Sorting nodes - compacted layout
            if (is_sink) {
                int col = sink_nodes_count / NODES_PER_COLUMN;
                int row = sink_nodes_count % NODES_PER_COLUMN;
                node.x = 600 + col * COLUMN_WIDTH;  // Sinks closer (reduced from 750)
                node.y = 50 + row * ROW_HEIGHT;
                sink_nodes_count++;
            } else {
                int col = source_nodes_count / NODES_PER_COLUMN;
                int row = source_nodes_count % NODES_PER_COLUMN;
                node.x = 50 + col * COLUMN_WIDTH;   // Sources on the left
                node.y = 50 + row * ROW_HEIGHT;
                source_nodes_count++;
            }

            canvas.add_node (node);
        }
        
        private void on_node_removed (uint id) {
            canvas.remove_node (id);
        }
        
        private void on_port_added (uint node_id, uint port_id, string name, 
                                    bool is_input, Canvas.PortType port_type, Backend.PortFlags _flags) {
            var direction = is_input ? Canvas.PortDirection.INPUT : Canvas.PortDirection.OUTPUT;
            var port = new Canvas.Port (port_id, name, direction, port_type);
            canvas.add_port_to_node (node_id, port);
        }
        
        private void on_link_added (uint _link_id, uint out_port, uint in_port) {
            ignore_graph_updates = true;
            canvas.add_connection (out_port, in_port);
            ignore_graph_updates = false;
        }
        
        private void on_link_removed (uint _link_id, uint out_port, uint in_port) {
            ignore_graph_updates = true;
            canvas.remove_connection_by_ports (out_port, in_port);
            ignore_graph_updates = false;
        }
        
        private void on_canvas_connection_created (uint source_id, uint target_id) {
            if (ignore_graph_updates) return;
            
            if (backend != null && backend.connected) {
                try {
                    backend.create_link (source_id, target_id);
                } catch (Error e) {
                    warning ("Failed to create link: %s", e.message);
                }
            }
        }
        
        private void on_canvas_connection_removed (uint source_id, uint target_id) {
            if (ignore_graph_updates) return;
            
            if (backend != null && backend.connected) {
                try {
                    backend.destroy_link_by_ports (source_id, target_id);
                } catch (Error e) {
                    warning ("Failed to destroy link: %s", e.message);
                }
            }
        }
        
        private void on_refresh () {
            source_nodes_count = 0;
            sink_nodes_count = 0;
            canvas.clear ();
            if (backend != null) {
                backend.refresh ();
            }
        }
        
        private void on_disconnect_all () {
            var dialog = new Adw.AlertDialog (
                "Disconnect All?",
                "This will remove all connections. This action cannot be undone."
            );
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("disconnect", "Disconnect All");
            dialog.set_response_appearance ("disconnect", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.default_response = "cancel";
            
            dialog.response.connect ((_, response) => {
                if (response == "disconnect") {
                    canvas.disconnect_all ();
                }
            });
            
            dialog.present (this);
        }
        
        private void show_error_dialog (string title, string message) {
            var dialog = new Adw.AlertDialog (title, message);
            dialog.add_response ("ok", "OK");
            dialog.present (this);
        }
    }
}
