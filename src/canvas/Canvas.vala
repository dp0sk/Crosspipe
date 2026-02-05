namespace Crosspipe.Canvas {
    public class GraphCanvas : Gtk.DrawingArea, Gtk.Scrollable {
        // Collections
        private Gee.HashMap<uint, Node> nodes;
        private Gee.ArrayList<Connection> connections;
        private Gee.ArrayList<Node> selected_nodes;
        
        private bool pending_initial_fit = false;
        
        // View transform
        private double _zoom = 1.0;
        public double zoom {
            get { return _zoom; }
            set {
                double old_zoom = _zoom;
                _zoom = value.clamp (0.1, 4.0);
                
                if (hadjustment != null && vadjustment != null && _zoom != old_zoom) {
                     update_adjustments_for_zoom (old_zoom);
                }
                
                queue_draw ();
            }
        }
        
        // Scrollable implementation
        public Gtk.Adjustment hadjustment { get; construct set; }
        public Gtk.Adjustment vadjustment { get; construct set; }
        public Gtk.ScrollablePolicy hscroll_policy { get; set; }
        public Gtk.ScrollablePolicy vscroll_policy { get; set; }
        
        public bool get_border (out Gtk.Border border) {
            border = {0, 0, 0, 0};
            return false;
        }
        
        private const double CANVAS_SIZE = 5000.0;
        
        public double pan_x { 
            get { return hadjustment != null ? -hadjustment.value : 0; }
            set { if (hadjustment != null) hadjustment.value = -value; }
        }
        
        public double pan_y { 
            get { return vadjustment != null ? -vadjustment.value : 0; }
            set { if (vadjustment != null) vadjustment.value = -value; }
        }
        
        // Interaction state
        private Node? hovered_node = null;
        private Port? hovered_port = null;
        private Connection? hovered_connection = null;
        private Node? dragging_node = null;
        private Port? connecting_port = null;
        private Connection? temp_connection = null;
        private bool panning = false;
        private double last_x = 0;
        private double last_y = 0;
        private double last_mouse_x = 0;
        private double last_mouse_y = 0;
        
        // Zoom gesture state
        private double zoom_gesture_initial_zoom = 1.0;
        
        // Context menu state
        private Node? context_menu_node = null;
        
        // Selection
        private bool selecting = false;
        private double select_start_x = 0;
        private double select_start_y = 0;
        private double select_end_x = 0;
        private double select_end_y = 0;

        // Undo/Redo
        public Commands.CommandManager command_manager { get; private set; }
        
        // Grid
        public bool show_grid { get; set; default = true; }
        private const double GRID_SIZE = 20.0;
        
        // Signals
        public signal void stats_changed (int node_count, int connection_count);
        public signal void connection_created (uint source_port_id, uint target_port_id);
        public signal void connection_removed (uint source_port_id, uint target_port_id);
        public signal void node_selected (Node? node);
        
        construct {
            nodes = new Gee.HashMap<uint, Node> ();
            connections = new Gee.ArrayList<Connection> ();
            selected_nodes = new Gee.ArrayList<Node> ();
            command_manager = new Commands.CommandManager ();
            
            // Enable focus for keyboard events
            focusable = true;
            can_focus = true;
            
            // Mouse click handler
            var click = new Gtk.GestureClick ();
            click.button = 0;  // All buttons
            click.pressed.connect (on_click_pressed);
            click.released.connect (on_click_released);
            add_controller (click);
            
            // Mouse motion handler
            var motion = new Gtk.EventControllerMotion ();
            motion.motion.connect (on_motion);
            motion.leave.connect (on_leave);
            add_controller (motion);
            
            // Scroll handler (for zoom)
            var scroll = new Gtk.EventControllerScroll (
                Gtk.EventControllerScrollFlags.BOTH_AXES
            );
            scroll.scroll.connect (on_scroll);
            add_controller (scroll);
            
            // Drag handler (for panning and moving nodes)
            var drag = new Gtk.GestureDrag ();
            drag.drag_begin.connect (on_drag_begin);
            drag.drag_update.connect (on_drag_update);
            drag.drag_end.connect (on_drag_end);
            add_controller (drag);
            
            // Keyboard handler
            var key = new Gtk.EventControllerKey ();
            key.key_pressed.connect (on_key_pressed);
            add_controller (key);
            
            // Zoom gesture handler (Touchpad pinch)
            var zoom_gesture = new Gtk.GestureZoom ();
            zoom_gesture.begin.connect (on_zoom_begin);
            zoom_gesture.scale_changed.connect (on_zoom_scale_changed);
            add_controller (zoom_gesture);
            
            // Set draw function
            set_draw_func (draw_canvas);
            
            // Listen to theme changes
            Adw.StyleManager.get_default ().notify["dark"].connect (() => {
                foreach (var node in nodes.values) {
                    node.update_theme (); 
                }
                queue_draw ();
            });

            // Request minimum size
            set_size_request (400, 300);
        }
        
        public override void size_allocate (int width, int height, int baseline) {
            base.size_allocate (width, height, baseline);
            configure_adjustments (width, height);
            
            if (pending_initial_fit && !nodes.is_empty) {
                pending_initial_fit = false;
                Idle.add (() => {
                    fit_to_content ();
                    return false;
                });
            }
        }
        
        private void configure_adjustments (int width, int height) {
            if (hadjustment == null || vadjustment == null) return;
            
            double total_width = double.max (CANVAS_SIZE * zoom, width);
            double total_height = double.max (CANVAS_SIZE * zoom, height);
            
            // Configure hadjustment
            hadjustment.configure (
                hadjustment.value,
                -(total_width / 2.0),
                (total_width / 2.0),
                width * 0.1,
                width * 0.9,
                width
            );
            
            // Configure vadjustment
            vadjustment.configure (
                vadjustment.value,
                -(total_height / 2.0),
                (total_height / 2.0),
                height * 0.1,
                height * 0.9,
                height
            );
        }
        
        private void update_adjustments_for_zoom (double old_zoom) {
             if (hadjustment == null || vadjustment == null) return;
             
             double view_width = get_width ();
             double view_height = get_height ();
             
             // Center of viewport in screen coordinates
             double center_x = view_width / 2.0;
             double center_y = view_height / 2.0;
             
             // Center in canvas coordinates (using old zoom)
             double canvas_center_x = (center_x + hadjustment.value) / old_zoom;
             double canvas_center_y = (center_y + vadjustment.value) / old_zoom;
             
             // New adjustment values to keep canvas_center at center of viewport
             double new_hadj = (canvas_center_x * zoom) - center_x;
             double new_vadj = (canvas_center_y * zoom) - center_y;
             
             hadjustment.value = new_hadj;
             vadjustment.value = new_vadj;
             
             configure_adjustments (get_width (), get_height ());
        }
        
        private void draw_canvas (Gtk.DrawingArea area, Cairo.Context cr, 
                                  int width, int height) {
            // Background
            Gdk.RGBA bg_color;
            if (!get_style_context ().lookup_color ("window_bg_color", out bg_color)) {
                bg_color = { 0.12f, 0.12f, 0.14f, 1.0f };
            }
            Gdk.cairo_set_source_rgba (cr, bg_color);
            cr.paint ();
            
            // Apply view transform
            cr.save ();
            cr.translate (pan_x, pan_y);
            cr.scale (zoom, zoom);
            
            // Draw grid
            if (show_grid) {
                draw_grid (cr, width, height);
            }
            
            // Draw connections
            foreach (var conn in connections) {
                conn.draw (cr, get_style_context ());
            }
            
            // Draw temporary connection while dragging
            if (temp_connection != null) {
                temp_connection.draw (cr, get_style_context ());
            }
            
            // Draw nodes
            foreach (var entry in nodes.entries) {
                entry.value.draw (cr, get_style_context ());
            }
            
            // Draw selection rectangle
            if (selecting) {
                draw_selection_rect (cr);
            }
            
            cr.restore ();
        }
        
        private void draw_grid (Cairo.Context cr, int width, int height) {
            Gdk.RGBA fg_color;
            if (!get_style_context ().lookup_color ("window_fg_color", out fg_color)) {
                fg_color = { 1.0f, 1.0f, 1.0f, 1.0f };
            }
            cr.set_source_rgba (fg_color.red, fg_color.green, fg_color.blue, 0.05);
            cr.set_line_width (1);
            
            double grid = GRID_SIZE;
            double start_x = -pan_x / zoom;
            double start_y = -pan_y / zoom;
            double end_x = (width - pan_x) / zoom;
            double end_y = (height - pan_y) / zoom;
            
            // Align to grid
            start_x = Math.floor (start_x / grid) * grid;
            start_y = Math.floor (start_y / grid) * grid;
            
            // Vertical lines
            for (double x = start_x; x < end_x; x += grid) {
                cr.move_to (x, start_y);
                cr.line_to (x, end_y);
            }
            
            // Horizontal lines
            for (double y = start_y; y < end_y; y += grid) {
                cr.move_to (start_x, y);
                cr.line_to (end_x, y);
            }
            
            cr.stroke ();
        }
        
        private void draw_selection_rect (Cairo.Context cr) {
            double x1 = double.min (select_start_x, select_end_x);
            double y1 = double.min (select_start_y, select_end_y);
            double w = Math.fabs (select_end_x - select_start_x);
            double h = Math.fabs (select_end_y - select_start_y);
            
            Gdk.RGBA accent_color;
            if (!get_style_context ().lookup_color ("accent_bg_color", out accent_color)) {
                accent_color = { 0.4f, 0.6f, 1.0f, 1.0f };
            }

            // Fill
            cr.set_source_rgba (accent_color.red, accent_color.green, accent_color.blue, 0.2);
            DrawingHelpers.rounded_rectangle (cr, x1, y1, w, h, 5);
            cr.fill ();
            
            // Border
            cr.set_source_rgba (accent_color.red, accent_color.green, accent_color.blue, 0.8);
            cr.set_line_width (1);
            DrawingHelpers.rounded_rectangle (cr, x1, y1, w, h, 5);
            cr.stroke ();
        }
        
        private void screen_to_canvas (double sx, double sy, out double cx, out double cy) {
            cx = (sx - pan_x) / zoom;
            cy = (sy - pan_y) / zoom;
        }
        
        private void update_hovered_item (double sx, double sy) {
            double cx, cy;
            screen_to_canvas (sx, sy, out cx, out cy);
            
            // Reset previous hover states
            if (hovered_node != null) {
                hovered_node.hovered = false;
            }
            if (hovered_port != null) {
                hovered_port.hovered = false;
            }
            if (hovered_connection != null) {
                hovered_connection.hovered = false;
            }
            
            hovered_node = null;
            hovered_port = null;
            hovered_connection = null;
            
            // Check connections first
            foreach (var conn in connections) {
                if (conn.contains_point (cx, cy)) {
                    hovered_connection = conn;
                }
            }
            
            // Check nodes
            foreach (var entry in nodes.entries) {
                var node = entry.value;
                bool hit = false;
                
                // Check ports first
                var port = node.port_at_point (cx, cy);
                if (port != null) {
                    hovered_port = port;
                    hovered_node = node;
                    hit = true;
                }
                // Check node body
                else if (node.contains_point (cx, cy)) {
                    hovered_node = node;
                    hovered_port = null;
                    hit = true;
                }
                
                if (hit) {
                    hovered_connection = null;
                }
            }
            
            // Apply new hover states
            if (hovered_connection != null) hovered_connection.hovered = true;
            if (hovered_node != null) hovered_node.hovered = true;
            if (hovered_port != null) hovered_port.hovered = true;
            
            queue_draw ();
        }
        
        // Event handlers
        private void on_click_pressed (Gtk.GestureClick gesture, int n_press, 
                                       double x, double y) {
            grab_focus ();
            
            uint button = gesture.get_current_button ();
            
            if (button == 1) {  // Left click
                double cx, cy;
                screen_to_canvas (x, y, out cx, out cy);
                
                // Check if clicking on a port (to start connection)
                if (hovered_port != null) {
                    // Select connections attached to this port
                    clear_selection ();
                    foreach (var conn in connections) {
                        if (conn.source_port == hovered_port || conn.target_port == hovered_port) {
                            conn.selected = true;
                        }
                    }
                    queue_draw ();

                    connecting_port = hovered_port;
                    temp_connection = new Connection.temporary (connecting_port, cx, cy);
                    return;
                }
                
                // Check if clicking on a node
                if (hovered_node != null) {
                    if (n_press == 2) {
                        // Double click [for fun lol]
                    } else {
                        // Start dragging
                        if (!hovered_node.selected) {
                            clear_selection ();
                            hovered_node.selected = true;
                            selected_nodes.add (hovered_node);
                            
                            // Select connections attached to this node
                            foreach (var conn in connections) {
                                if ((conn.source_port != null && conn.source_port.parent_node == hovered_node) ||
                                    (conn.target_port != null && conn.target_port.parent_node == hovered_node)) {
                                    conn.selected = true;
                                }
                            }
                        }
                        
                        foreach (var node in selected_nodes) {
                            node.dragging = true;
                            node.drag_start_x = node.x;
                            node.drag_start_y = node.y;
                        }
                        dragging_node = hovered_node;
                    }
                    node_selected (hovered_node);
                    queue_draw ();
                    return;
                }
                
                // Check if clicking on a connection
                if (hovered_connection != null) {
                    // Select connection (for deletion)
                    clear_selection ();
                    hovered_connection.selected = true;
                    queue_draw ();
                    return;
                }
                
                // Clicking on empty space
                clear_selection ();
                
                // Start selection rectangle
                selecting = true;
                select_start_x = cx;
                select_start_y = cy;
                select_end_x = cx;
                select_end_y = cy;
                
            } else if (button == 2) {  // Middle click - start panning
                panning = true;
                last_x = x;
                last_y = y;
                
            } else if (button == 3) {  // Right click - context menu
                show_context_menu (x, y);
            }
        }
        
        private void on_click_released (Gtk.GestureClick gesture, int _n_press, 
                                        double _x, double _y) {
            uint button = gesture.get_current_button ();
            
            if (button == 1) {
                // Finish connection
                if (connecting_port != null && temp_connection != null) {
                    if (hovered_port != null && hovered_port != connecting_port) {
                        // Check if connection is valid (output -> input)
                        Port source, target;
                        if (connecting_port.direction == PortDirection.OUTPUT && 
                            hovered_port.direction == PortDirection.INPUT) {
                            source = connecting_port;
                            target = hovered_port;
                        } else if (connecting_port.direction == PortDirection.INPUT && 
                                   hovered_port.direction == PortDirection.OUTPUT) {
                            source = hovered_port;
                            target = connecting_port;
                        } else {
                            // Invalid connection
                            source = null;
                            target = null;
                        }
                        
                        if (source != null && target != null) {
                            // Check if connection already exists
                            bool exists = false;
                            foreach (var conn in connections) {
                                if (conn.source_port == source && conn.target_port == target) {
                                    exists = true;
                                    break;
                                }
                            }
                            
                            if (!exists) {
                                var cmd = new Commands.ConnectCommand (this, source.port_id, target.port_id);
                                command_manager.execute (cmd);
                                update_stats ();
                            }
                        }
                    }
                    
                    temp_connection = null;
                    connecting_port = null;
                }
                
                // Finish dragging
                if (dragging_node != null) {
                    foreach (var node in selected_nodes) {
                        node.dragging = false;
                    }
                    dragging_node = null;
                }
                
                // Finish selection rectangle
                if (selecting) {
                    selecting = false;
                    select_nodes_in_rect ();
                }
                
            } else if (button == 2) {
                panning = false;
            }
            
            queue_draw ();
        }
        
        private void on_motion (Gtk.EventControllerMotion controller, double x, double y) {
            last_mouse_x = x;
            last_mouse_y = y;
            update_hovered_item (x, y);
            
            // Update temp connection end point
            if (temp_connection != null) {
                double cx, cy;
                screen_to_canvas (x, y, out cx, out cy);
                temp_connection.temp_end_x = cx;
                temp_connection.temp_end_y = cy;
                queue_draw ();
            }
            
            // Update selection rectangle
            if (selecting) {
                double cx, cy;
                screen_to_canvas (x, y, out cx, out cy);
                select_end_x = cx;
                select_end_y = cy;
                queue_draw ();
            }
        }
        
        private void on_leave (Gtk.EventControllerMotion controller) {
            if (hovered_node != null) {
                hovered_node.hovered = false;
                hovered_node = null;
            }
            if (hovered_port != null) {
                hovered_port.hovered = false;
                hovered_port = null;
            }
            if (hovered_connection != null) {
                hovered_connection.hovered = false;
                hovered_connection = null;
            }
            queue_draw ();
        }
        
        private void on_drag_begin (Gtk.GestureDrag gesture, double x, double y) {
            last_x = x;
            last_y = y;
        }
        
        private void on_drag_update (Gtk.GestureDrag gesture, double offset_x, double offset_y) {
            if (dragging_node != null) {
                // Move dragged nodes
                double dx = offset_x / zoom;
                double dy = offset_y / zoom;
                
                foreach (var node in selected_nodes) {
                    node.x = node.drag_start_x + dx;
                    node.y = node.drag_start_y + dy;
                }
                queue_draw ();
                return;
            }
            
            if (panning || gesture.get_current_button () == 2) {
                // Pan the view
                double start_x, start_y;
                gesture.get_start_point (out start_x, out start_y);
                pan_x = offset_x + start_x - last_x + pan_x;
                pan_y = offset_y + start_y - last_y + pan_y;
                last_x = start_x + offset_x;
                last_y = start_y + offset_y;
                queue_draw ();
            }
        }
        
        private void on_drag_end (Gtk.GestureDrag gesture, double _offset_x, double _offset_y) {
            panning = false;
        }
        
        private void on_zoom_begin (Gtk.Gesture gesture, Gdk.EventSequence? _sequence) {
            zoom_gesture_initial_zoom = zoom;
        }


        private void on_zoom_scale_changed (Gtk.GestureZoom gesture, double scale) {
            if (hadjustment == null || vadjustment == null) return;
            
            double new_zoom = (zoom_gesture_initial_zoom * scale).clamp (0.1, 4.0);
            
            if (new_zoom == zoom) return;
            
            double center_x, center_y;
            gesture.get_bounding_box_center (out center_x, out center_y);
            
            double old_zoom = zoom;
            
            double cx = (center_x + hadjustment.value) / old_zoom;
            double cy = (center_y + vadjustment.value) / old_zoom;
            
            double new_hadj = cx * new_zoom - center_x;
            double new_vadj = cy * new_zoom - center_y;
            
            hadjustment.value = new_hadj;
            vadjustment.value = new_vadj;
            
            _zoom = new_zoom;
            configure_adjustments (get_width (), get_height ());
            queue_draw ();
            notify_property ("zoom");
        }
        
        private bool on_scroll (Gtk.EventControllerScroll controller, 
                                double _dx, double dy) {
            // Zoom with scroll wheel if Ctrl is pressed
            var state = controller.get_current_event_state ();
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                double old_zoom = zoom;
                double zoom_factor = 1.1;
                
                // Calculate temporary new zoom
                double new_zoom = old_zoom;
                if (dy < 0) {
                    new_zoom *= zoom_factor;
                } else if (dy > 0) {
                    new_zoom /= zoom_factor;
                }
                new_zoom = new_zoom.clamp (0.1, 4.0);
                
                if (new_zoom == old_zoom) return true;
                
                if (hadjustment == null || vadjustment == null) {
                    zoom = new_zoom;
                    return true;
                }
                
                // Cursor position in screen space
                double cursor_x = last_mouse_x; 
                double cursor_y = last_mouse_y;
                
                double canvas_cursor_x = (cursor_x + hadjustment.value) / old_zoom;
                double canvas_cursor_y = (cursor_y + vadjustment.value) / old_zoom;
                
                double new_hadj = canvas_cursor_x * new_zoom - cursor_x;
                double new_vadj = canvas_cursor_y * new_zoom - cursor_y;
                
                hadjustment.value = new_hadj;
                vadjustment.value = new_vadj;
                
                _zoom = new_zoom;
                configure_adjustments (get_width (), get_height ());
                queue_draw ();
                
                notify_property ("zoom");
                
                return true;
            }
            
            return false; // Propagate to ScrolledWindow for normal scrolling
        }
        
        private bool on_key_pressed (Gtk.EventControllerKey controller, 
                                     uint keyval, uint _keycode, 
                                     Gdk.ModifierType state) {
            switch (keyval) {
                case Gdk.Key.Delete:
                case Gdk.Key.BackSpace:
                    delete_selected ();
                    return true;
                    
                case Gdk.Key.Escape:
                    clear_selection ();
                    if (temp_connection != null) {
                        temp_connection = null;
                        connecting_port = null;
                    }
                    queue_draw ();
                    return true;
                    
                case Gdk.Key.a:
                    if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                        select_all ();
                        return true;
                    }
                    break;
            }
            return false;
        }
        
        private void show_context_menu (double x, double y) {
            context_menu_node = hovered_node;
            var menu = new Menu ();
            
            if (hovered_connection != null) {
                // Ensure connection is selected so the action works
                if (!hovered_connection.selected) {
                    clear_selection ();
                    hovered_connection.selected = true;
                    queue_draw ();
                }
                menu.append ("Disconnect", "win.disconnect-selected");
            } else if (hovered_node != null) {
                menu.append ("Disconnect All Ports", "win.disconnect-node");
            } else {
                menu.append ("Select All", "win.select-all");
                menu.append ("Refresh", "win.refresh");
            }
            
            var popover = new Gtk.PopoverMenu.from_model (menu);
            popover.set_parent (this);
            popover.set_pointing_to ({ (int) x, (int) y, 1, 1 });
            popover.popup ();
        }
        
        private void clear_selection () {
            foreach (var node in selected_nodes) {
                node.selected = false;
            }
            selected_nodes.clear ();
            
            foreach (var conn in connections) {
                conn.selected = false;
            }
            
            node_selected (null);
        }
        
        public void select_all () {
            foreach (var entry in nodes.entries) {
                entry.value.selected = true;
                if (!selected_nodes.contains (entry.value)) {
                    selected_nodes.add (entry.value);
                }
            }
            queue_draw ();
        }
        
        private void select_nodes_in_rect () {
            double x1 = double.min (select_start_x, select_end_x);
            double y1 = double.min (select_start_y, select_end_y);
            double x2 = double.max (select_start_x, select_end_x);
            double y2 = double.max (select_start_y, select_end_y);
            
            foreach (var entry in nodes.entries) {
                var node = entry.value;
                // Check if node intersects with selection rectangle
                if (node.x + node.width >= x1 && node.x <= x2 &&
                    node.y + node.height >= y1 && node.y <= y2) {
                    node.selected = true;
                    if (!selected_nodes.contains (node)) {
                        selected_nodes.add (node);
                    }
                    
                    // Select connections attached to this node
                    foreach (var conn in connections) {
                        if ((conn.source_port != null && conn.source_port.parent_node == node) ||
                            (conn.target_port != null && conn.target_port.parent_node == node)) {
                            conn.selected = true;
                        }
                    }
                }
            }
            
            // Check if connections intersect with selection rectangle
            foreach (var conn in connections) {
                if (conn.intersects_rect (x1, y1, x2, y2)) {
                    conn.selected = true;
                }
            }
            queue_draw ();
        }
        
        public void delete_selected () {
            // Delete selected connections
            var to_remove = new Gee.ArrayList<Connection> ();
            foreach (var conn in connections) {
                if (conn.selected) {
                    to_remove.add (conn);
                    connection_removed (conn.source_port_id, conn.target_port_id);
                }
            }
            connections.remove_all (to_remove);
            
            update_stats ();
            queue_draw ();
        }
        
        public void disconnect_hovered_node () {
            Node? target = context_menu_node;
            if (target == null) target = hovered_node;
            
            if (target == null) return;
            
            var to_remove = new Gee.ArrayList<Connection> ();
            foreach (var conn in connections) {
                if ((conn.source_port != null && conn.source_port.parent_node == target) ||
                    (conn.target_port != null && conn.target_port.parent_node == target)) {
                    to_remove.add (conn);
                    connection_removed (conn.source_port_id, conn.target_port_id);
                }
            }
            connections.remove_all (to_remove);
            update_stats ();
            queue_draw ();
        }
        
        private void update_stats () {
            stats_changed (nodes.size, connections.size);
        }
        
        public void add_node (Node node) {
            nodes[node.node_id] = node;
            update_stats ();
            queue_draw ();
        }
        
        public void remove_node (uint id) {
            if (nodes.has_key (id)) {
                var node = nodes[id];
                
                // Remove connections to/from this node
                var to_remove = new Gee.ArrayList<Connection> ();
                foreach (var conn in connections) {
                    if ((conn.source_port != null && conn.source_port.parent_node == node) ||
                        (conn.target_port != null && conn.target_port.parent_node == node)) {
                        to_remove.add (conn);
                    }
                }
                connections.remove_all (to_remove);
                
                nodes.unset (id);
                update_stats ();
                queue_draw ();
            }
        }
        
        public void add_port_to_node (uint node_id, Port port) {
            if (nodes.has_key (node_id)) {
                nodes[node_id].add_port (port);
                queue_draw ();
            }
        }
        
        public void add_connection (uint source_port_id, uint target_port_id) {
            Port? source = find_port (source_port_id);
            Port? target = find_port (target_port_id);
            
            if (source != null && target != null) {
                // Check if already exists
                foreach (var conn in connections) {
                    if (conn.source_port == source && conn.target_port == target) {
                        return;
                    }
                }
                
                var conn = new Connection.between (source, target);
                connections.add (conn);
                connection_created (source_port_id, target_port_id);
                update_stats ();
                queue_draw ();
            }
        }
        
        public void remove_connection_by_ports (uint source_port_id, uint target_port_id) {
            Connection? to_remove = null;
            foreach (var conn in connections) {
                if (conn.source_port_id == source_port_id && 
                    conn.target_port_id == target_port_id) {
                    to_remove = conn;
                    break;
                }
            }
            if (to_remove != null) {
                connections.remove (to_remove);
                connection_removed (source_port_id, target_port_id);
                update_stats ();
                queue_draw ();
            }
        }
        
        private Port? find_port (uint port_id) {
            foreach (var entry in nodes.entries) {
                var port = entry.value.find_port (port_id);
                if (port != null) return port;
            }
            return null;
        }
        
        public void clear () {
            nodes.clear ();
            connections.clear ();
            selected_nodes.clear ();
            update_stats ();
            queue_draw ();
        }
        
        public void disconnect_all () {
            foreach (var conn in connections) {
                connection_removed (conn.source_port_id, conn.target_port_id);
            }
            connections.clear ();
            update_stats ();
            queue_draw ();
        }
        
        public void fit_to_content () {
            if (nodes.is_empty) return;
            
            // Current viewport size
            double view_w = get_width ();
            double view_h = get_height ();
            
            // If widget size is not yet available, delay fit until allocation
            if (view_w <= 1 || view_h <= 1) {
                pending_initial_fit = true;
                return;
            }
            
            double min_x = double.MAX;
            double min_y = double.MAX;
            double max_x = -double.MAX;
            double max_y = -double.MAX;
            
            foreach (var node in nodes.values) {
                if (node.x < min_x) min_x = node.x;
                if (node.y < min_y) min_y = node.y;
                if (node.x + node.width > max_x) max_x = node.x + node.width;
                if (node.y + node.height > max_y) max_y = node.y + node.height;
            }
            
            // Add some padding
            double padding = 50.0;
            double content_w = max_x - min_x + (padding * 2);
            double content_h = max_y - min_y + (padding * 2);
            
            // Calculate scale to fit
            double zoom_x = view_w / content_w;
            double zoom_y = view_h / content_h;
            double new_zoom = double.min (zoom_x, zoom_y);
            
            // Clamp zoom
            new_zoom = new_zoom.clamp (0.1, 4.0);
            
            // Center view
            double center_x = min_x + (max_x - min_x) / 2.0;
            double center_y = min_y + (max_y - min_y) / 2.0;
            
            if (hadjustment != null && vadjustment != null) {
                _zoom = new_zoom;
                configure_adjustments ((int) view_w, (int) view_h);
                
                hadjustment.value = (center_x * new_zoom) - (view_w / 2.0);
                vadjustment.value = (center_y * new_zoom) - (view_h / 2.0);
                
                queue_draw ();
                notify_property ("zoom");
            } else {
                 zoom = new_zoom;
            }
        }
        
        public Gee.Collection<Node> get_nodes () {
            return nodes.values;
        }
        
        public Gee.ArrayList<Connection> get_connections () {
            return connections;
        }
    }
}
