namespace Crosspipe.Canvas {

    // Port type
    public enum PortType {
        AUDIO,
        MIDI,
        VIDEO,
        OTHER;
        
        public Gdk.RGBA get_color () {
            switch (this) {
                case AUDIO:
                    return { 0.30f, 0.69f, 0.31f, 1.0f };  // Green rgba(76, 175, 80, 1)
                case MIDI:
                    return { 0.91f, 0.12f, 0.39f, 1.0f };  // Pink rgba(233, 30, 99, 1)
                case VIDEO:
                    return { 0.13f, 0.59f, 0.95f, 1.0f };  // Blue rgba(33, 150, 243, 1)
                default:
                    return { 0.62f, 0.62f, 0.62f, 1.0f };  // Gray
            }
        }
    }
    
    // Port direction
    public enum PortDirection {
        INPUT,
        OUTPUT
    }
    
    // Port item
    public class Port : CanvasItem {
        
        // Port properties
        public uint port_id { get; construct; }
        public string name { get; construct; }
        public PortDirection direction { get; construct; }
        public PortType port_type { get; construct; }
        
        // Parent node
        public weak Node? parent_node { get; set; default = null; }
        
        // Visual properties
        public const double PORT_RADIUS = 6.0;
        public const double PORT_HEIGHT = 22.0;
        public const double TEXT_MARGIN = 8.0;
        
        // Connection point
        public double connection_x {
            get {
                return (direction == PortDirection.INPUT) ? x : x + width;
            }
        }
        
        public double connection_y {
            get {
                return y + PORT_HEIGHT / 2;
            }
        }
        
        public Port (uint id, string name, PortDirection direction, PortType port_type) {
            Object (
                port_id: id,
                name: name,
                direction: direction,
                port_type: port_type
            );
            this.height = PORT_HEIGHT;
        }
        
        public string display_name {
            owned get {
                int last_colon = name.last_index_of_char (':');
                if (last_colon >= 0 && last_colon < name.length - 1) {
                    return name.substring (last_colon + 1);
                }
                return name;
            }
        }
        
        // Draw port
        public override void draw (Cairo.Context cr, Gtk.StyleContext ctx) {
            if (!visible) return;
            
            var color = port_type.get_color ();
            
            // Port
            double circle_x = direction == PortDirection.INPUT ? x : x + width;
            double circle_y = y + PORT_HEIGHT / 2;
            
            // Highlight on hover or selection
            if (hovered || selected) {
                cr.set_source_rgba (color.red, color.green, color.blue, 0.3);
                cr.arc (circle_x, circle_y, PORT_RADIUS + 3, 0, 2 * Math.PI);
                cr.fill ();
            }
            
            // Port main color
            Gdk.cairo_set_source_rgba (cr, color);
            cr.arc (circle_x, circle_y, PORT_RADIUS, 0, 2 * Math.PI);
            cr.fill ();
            
            // Port border
            Gdk.RGBA fg_color;
            if (!ctx.lookup_color ("window_fg_color", out fg_color)) {
                fg_color = { 1.0f, 1.0f, 1.0f, 1.0f };
            }

            cr.set_source_rgba (fg_color.red, fg_color.green, fg_color.blue, 0.8);
            cr.set_line_width (1.5);
            cr.arc (circle_x, circle_y, PORT_RADIUS, 0, 2 * Math.PI);
            cr.stroke ();
            
            // Text rendering
            cr.set_source_rgba (fg_color.red, fg_color.green, fg_color.blue, 0.9);
            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size (11);
            
            string text_to_draw = display_name;
            Cairo.TextExtents extents;
            cr.text_extents (text_to_draw, out extents);
            
            double text_x;
            if (direction == PortDirection.INPUT) {
                text_x = x + PORT_RADIUS + TEXT_MARGIN;
            } else {
                text_x = x + width - PORT_RADIUS - TEXT_MARGIN - extents.width;
            }
            
            cr.move_to (text_x, y + PORT_HEIGHT / 2 + extents.height / 2 - 1);
            cr.show_text (text_to_draw);
        }

        // Check if point is in port
        public override bool contains_point (double px, double py) {
            // Check circle hit with extra margin
            double circle_x = direction == PortDirection.INPUT ? x : x + width;
            double circle_y = y + PORT_HEIGHT / 2;
            
            double dx = px - circle_x;
            double dy = py - circle_y;
            double dist = Math.sqrt (dx * dx + dy * dy);
            
            return dist <= PORT_RADIUS + 4; // Increased click area
        }
    }
}
