namespace Crosspipe.Canvas {

    // Node item
    public class Node : CanvasItem {
        
        // Node properties
        public uint node_id { get; construct; }
        public string name { get; construct; }
        public bool is_sink { get; construct; }
        
        // Ports
        public Gee.ArrayList<Port> input_ports { get; private set; }
        public Gee.ArrayList<Port> output_ports { get; private set; }
        
        // Visual constants
        public const double HEADER_HEIGHT = 28.0;
        public const double CORNER_RADIUS = 12.0;
        public const double MIN_WIDTH = 160.0;
        public const double PADDING = 12.0;
        
        // Colors
        private Gdk.RGBA header_color;
        private Gdk.RGBA body_color;
        
        // Dragging state
        public bool dragging { get; set; default = false; }
        public double drag_start_x { get; set; }
        public double drag_start_y { get; set; }
        
        public Node (uint id, string name, bool is_sink) {
            Object (node_id: id, name: name, is_sink: is_sink);
            input_ports = new Gee.ArrayList<Port> ();
            output_ports = new Gee.ArrayList<Port> ();
            
            width = 180;
            height = Node.HEADER_HEIGHT + Node.PADDING * 2;
            
            if (is_sink) {
                header_color = { 0.20f, 0.30f, 0.45f, 1.0f };
                body_color = { 0.18f, 0.20f, 0.25f, 0.95f };
            } else {
                header_color = { 0.20f, 0.40f, 0.30f, 1.0f };
                body_color = { 0.18f, 0.22f, 0.20f, 0.95f };
            }
            
            update_size ();
        }
        
        public void add_port (Port port) {
            port.parent_node = this;
            
            if (port.direction == PortDirection.INPUT) {
                input_ports.add (port);
            } else {
                output_ports.add (port);
            }
            
            update_theme ();
            update_size ();
        }
        
        public Port? find_port (uint port_id) {
            foreach (var port in input_ports) {
                if (port.port_id == port_id) return port;
            }
            foreach (var port in output_ports) {
                if (port.port_id == port_id) return port;
            }
            return null;
        }

        public Port? find_port_by_name (string name) {
            foreach (var port in input_ports) {
                if (port.name == name) return port;
            }
            foreach (var port in output_ports) {
                if (port.name == name) return port;
            }
            return null;
        }
        
        // Update header/body colors based on theme
        public void update_theme () {
            PortType type = PortType.OTHER;
            bool found = false;
            
            if (input_ports.size > 0) {
                type = input_ports[0].port_type;
                found = true;
            } else if (output_ports.size > 0) {
                type = output_ports[0].port_type;
                found = true;
            }
            
            bool is_dark = Adw.StyleManager.get_default ().dark;
            
            if (found) {
                var c = type.get_color ();
                if (is_dark) {
                    header_color = { c.red * 0.7f, c.green * 0.7f, c.blue * 0.7f, 1.0f };
                    body_color = { c.red * 0.15f + 0.05f, c.green * 0.15f + 0.05f, c.blue * 0.15f + 0.05f, 0.95f };
                } else {
                    header_color = { c.red * 0.8f, c.green * 0.8f, c.blue * 0.8f, 1.0f };
                    body_color = { c.red * 0.05f + 0.92f, c.green * 0.05f + 0.92f, c.blue * 0.05f + 0.92f, 0.98f };
                }
            } else {
                if (is_sink) {
                    if (is_dark) {
                        header_color = { 0.20f, 0.30f, 0.45f, 1.0f };
                        body_color = { 0.18f, 0.20f, 0.25f, 0.95f };
                    } else {
                        header_color = { 0.30f, 0.45f, 0.65f, 1.0f };
                        body_color = { 0.90f, 0.92f, 0.95f, 0.98f };
                    }
                } else {
                    if (is_dark) {
                        header_color = { 0.20f, 0.40f, 0.30f, 1.0f };
                        body_color = { 0.18f, 0.22f, 0.20f, 0.95f };
                    } else {
                        header_color = { 0.30f, 0.60f, 0.45f, 1.0f };
                        body_color = { 0.90f, 0.95f, 0.92f, 0.98f };
                    }
                }
            }
        }

        // Update node dimensions
        private void update_size () {
            double max_input_width = 0;
            foreach (var port in input_ports) {
                max_input_width = double.max (max_input_width, estimate_text_width(port.display_name));
            }
            
            double max_output_width = 0;
            foreach (var port in output_ports) {
                max_output_width = double.max (max_output_width, estimate_text_width(port.display_name));
            }
            
            double port_icon_width = Port.PORT_RADIUS * 2 + Port.TEXT_MARGIN;
            double ports_width = 0;
            
            if (input_ports.size > 0) ports_width += max_input_width + port_icon_width;
            if (output_ports.size > 0) ports_width += max_output_width + port_icon_width;
            
            double header_width = estimate_text_width(name, true) + PADDING * 4;
            
            width = double.max (MIN_WIDTH, double.max (header_width, ports_width));
            
            int max_ports = int.max (input_ports.size, output_ports.size);
            height = HEADER_HEIGHT + PADDING + (max_ports * Port.PORT_HEIGHT) + PADDING;
            
            update_port_positions ();
        }
        
        private double estimate_text_width (string text, bool bold = false) {
            return text.length * (bold ? 8.5 : 7.5); 
        }
        
        protected override void on_geometry_changed () {
            update_port_positions ();
        }
        
        public void update_port_positions () {
            double port_y = y + HEADER_HEIGHT + PADDING;
            
            foreach (var port in input_ports) {
                port.x = x;
                port.y = port_y;
                port.width = width;
                port_y += Port.PORT_HEIGHT;
            }
            
            port_y = y + HEADER_HEIGHT + PADDING;
            
            foreach (var port in output_ports) {
                port.x = x;
                port.y = port_y;
                port.width = width;
                port_y += Port.PORT_HEIGHT;
            }
        }
        
        public override void draw (Cairo.Context cr, Gtk.StyleContext ctx) {
            if (!visible) return;
            
            // Shadow
            DrawingHelpers.draw_shadow (cr, x, y, width, height, CORNER_RADIUS, 4);
            
            // Body background
            Gdk.cairo_set_source_rgba (cr, body_color);
            DrawingHelpers.rounded_rectangle (cr, x, y, width, height, CORNER_RADIUS);
            cr.fill ();
            
            // Header background
            cr.save ();
            DrawingHelpers.rounded_rectangle (cr, x, y, width, height, CORNER_RADIUS);
            cr.clip ();
            
            Gdk.cairo_set_source_rgba (cr, header_color);
            cr.rectangle (x, y, width, HEADER_HEIGHT);
            cr.fill ();
            cr.restore ();
            
            // Selection/hover border
            Gdk.RGBA accent_color;
            if (!ctx.lookup_color ("accent_bg_color", out accent_color)) {
                accent_color = { 0.4f, 0.7f, 1.0f, 0.8f };
            }

            if (selected) {
                Gdk.cairo_set_source_rgba (cr, accent_color);
                cr.set_line_width (2.5);
                DrawingHelpers.rounded_rectangle (cr, x, y, width, height, CORNER_RADIUS);
                cr.stroke ();
            } else if (hovered) {
                cr.set_source_rgba (accent_color.red, accent_color.green, accent_color.blue, 0.4);
                cr.set_line_width (1.5);
                DrawingHelpers.rounded_rectangle (cr, x, y, width, height, CORNER_RADIUS);
                cr.stroke ();
            } else {
                // Normal border
                Gdk.RGBA border_color;
                if (!ctx.lookup_color ("window_fg_color", out border_color)) {
                    border_color = { 0.4f, 0.4f, 0.4f, 1.0f };
                }
                cr.set_source_rgba (border_color.red, border_color.green, border_color.blue, 0.2);
                cr.set_line_width (1);
                DrawingHelpers.rounded_rectangle (cr, x, y, width, height, CORNER_RADIUS);
                cr.stroke ();
            }
            
            // Header text (node name) - always white on colored header looks okay, 
            // but let's use a theme-aware approach if needed. 
            // Actually, headers are quite dark even in light theme in my implementation above.
            cr.set_source_rgba (1, 1, 1, 0.95);
            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            cr.set_font_size (11);
            
            // Truncate name if too long
            string display_name = name;
            Cairo.TextExtents extents;
            cr.text_extents (display_name, out extents);
            
            if (extents.width > width - PADDING * 2) {
                // Truncate with ellipsis
                double available_width = width - PADDING * 3;
                double avg_char_width = extents.width / display_name.length;
                int estimated_chars = (int)(available_width / avg_char_width);
                
                if (estimated_chars < display_name.length) {
                    display_name = display_name.substring(0, int.max(0, estimated_chars));
                }
                
                cr.text_extents (display_name + "...", out extents);
                while (display_name.length > 1 && extents.width > available_width) {
                    display_name = display_name.substring (0, display_name.length - 1);
                    cr.text_extents (display_name + "...", out extents);
                }
                display_name = display_name + "...";
            }
            
            cr.move_to (x + PADDING, y + HEADER_HEIGHT / 2 + extents.height / 2 - 2);
            cr.show_text (display_name);
            
            // Draw ports
            foreach (var port in input_ports) {
                port.draw (cr, ctx);
            }
            foreach (var port in output_ports) {
                port.draw (cr, ctx);
            }
        }
        
        public override bool contains_point (double px, double py) {
            return px >= x && px <= x + width &&
                   py >= y && py <= y + height;
        }
        
        public Port? port_at_point (double px, double py) {
            foreach (var port in input_ports) {
                if (port.contains_point (px, py)) {
                    return port;
                }
            }
            foreach (var port in output_ports) {
                if (port.contains_point (px, py)) {
                    return port;
                }
            }
            return null;
        }
    }
}
