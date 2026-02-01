namespace Crosspipe.Canvas {

    // Connection item
    public class Connection : CanvasItem {
        
        // Connected ports
        public weak Port? source_port { get; set; }  // Port1 (can be input or output)
        public weak Port? target_port { get; set; }  // Port2 (can be input or output)
        
        // For drawing temporary connection while dragging
        public double temp_end_x { get; set; }
        public double temp_end_y { get; set; }
        public bool is_temporary { get; set; default = false; }
        
        // Visual properties
        public bool dimmed { get; set; default = false; }
        public const double LINE_WIDTH = 2.0;
        public const double SHADOW_WIDTH = 3.0;
        public const double HOVER_LINE_WIDTH = 2.0;
        public const double ARROW_SIZE = 8.0;
        
        // Static configuration
        public static bool connect_through_nodes { get; set; default = false; }
        
        public Connection () {
            Object ();
        }
        
        public Connection.between (Port port1, Port port2) {
            Object ();
            this.source_port = port1;
            this.target_port = port2;
        }
        
        public Connection.temporary (Port source, double end_x, double end_y) {
            Object ();
            this.source_port = source;
            this.temp_end_x = end_x;
            this.temp_end_y = end_y;
            this.is_temporary = true;
        }
        
        // Calculate bezier geometry
        private void calculate_geometry (out double x1, out double y1, 
                                         out double cx1, out double cy1, 
                                         out double cx2, out double cy2, 
                                         out double x2, out double y2) {
            
            // Initialize output parameters
            x1 = y1 = cx1 = cy1 = cx2 = cy2 = x2 = y2 = 0.0;
            
            if (source_port == null) return;
            
            x1 = source_port.connection_x;
            y1 = source_port.connection_y;
            
            if (is_temporary) {
                x2 = temp_end_x;
                y2 = temp_end_y;
            } else if (target_port != null) {
                x2 = target_port.connection_x;
                y2 = target_port.connection_y;
            } else {
                return;
            }
            
            double dir1 = (source_port.direction == PortDirection.OUTPUT) ? 1.0 : -1.0;
            double dir2;
            
            if (is_temporary) {
                // If temporary, assume we connect to opposite type
                // If source is Output (Right), target is Input (Left tangent) -> dir2 = -1
                // If source is Input (Left), target is Output (Right tangent) -> dir2 = 1
                dir2 = (source_port.direction == PortDirection.OUTPUT) ? -1.0 : 1.0;
            } else if (target_port != null) {
                dir2 = (target_port.direction == PortDirection.OUTPUT) ? 1.0 : -1.0;
            } else {
                dir2 = -dir1;
            }
            
            // Apply small offset from port edge
            double d1 = 1.0;
            double pos1_x = x1 + dir1 * d1;
            double pos1_y = y1;
            double pos4_x = x2 + dir2 * d1;
            double pos4_y = y2;
            
            // Apply additional offset for curve start/end calculation base
            double d2 = 2.0;
            double pos1_2_x = pos1_x + dir1 * d2;
            double pos1_2_y = pos1_y;
            double pos3_4_x = pos4_x + dir2 * d2;
            double pos3_4_y = pos4_y;
            
            // Node geometry for obstacle avoidance
            double rect_w = 100.0;
            double h1 = 50.0;
            double node_center_y = y1; // Default
            
            Node? node1 = source_port.parent_node;
            if (node1 != null) {
                rect_w = node1.width;
                h1 = 0.5 * node1.height;
                double ports_top = node1.y + Node.HEADER_HEIGHT + Node.PADDING;
                double ports_bottom = node1.y + node1.height - Node.PADDING;
                node_center_y = (ports_top + ports_bottom) * 0.5;
            }
            
            double dh = y1 - node_center_y;
            double dx = pos3_4_x - pos1_2_x;
            
            // Calculate main curve offsets
            
            double x_max = rect_w + h1;
            double x_min = double.min(x_max, Math.fabs(dx));
            double x_offset = (dx * dir1 > 0.0 ? 0.5 : 1.0) * x_min;
            
            // Determine Y offset
            double y_offset = 0.0;
            if (connect_through_nodes) {
                 double h2 = 20.0;
                 double dy = Math.fabs(pos3_4_y - pos1_2_y);
                 y_offset = (dx * dir1 > -h2 || dy > h2) ? 0.0 : (dh > 0.0 ? h2 : -h2);
            } else {
                 y_offset = (dx * dir1 > 0.0) ? 0.0 : (dh > 0.0 ? x_min : -x_min);
            }
            
            // Calculate final control points
            
            cx1 = pos1_x + dir1 * Math.fabs(x_offset);
            cy1 = pos1_y + y_offset;
            
            cx2 = pos4_x + dir2 * Math.fabs(x_offset);
            cy2 = pos4_y + y_offset;
        }
        
        public override void draw (Cairo.Context cr, Gtk.StyleContext ctx) {
            if (!visible || source_port == null) return;
            
            double x1, y1, x2, y2, cx1, cy1, cx2, cy2;
            calculate_geometry (out x1, out y1, out cx1, out cy1, out cx2, out cy2, out x2, out y2);
            
            if (x2 == 0 && y2 == 0 && !is_temporary && target_port == null) return;

            // Get color from source port
            Gdk.RGBA color = source_port.port_type.get_color ();
            
            // Adjust alpha for dimmed state
            double alpha = dimmed ? 0.5 : 1.0;
            
            // Draw shadow (dark background for depth)
            cr.save ();
            cr.set_source_rgba (0, 0, 0, dimmed ? 0.16 : 0.31);
            cr.set_line_width (SHADOW_WIDTH);
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.move_to (x1 + 1.0, y1 + 1.0);
            cr.curve_to (cx1 + 1.0, cy1 + 1.0, cx2 + 1.0, cy2 + 1.0, x2 + 1.0, y2 + 1.0);
            cr.stroke ();
            cr.restore ();
            
            // Draw main connection line
            cr.save ();
            
            Gdk.RGBA accent_color;
            if (!ctx.lookup_color ("accent_bg_color", out accent_color)) {
                accent_color = { 0.3f, 0.6f, 1.0f, 1.0f };
            }

            if (selected) {
                cr.set_source_rgba (accent_color.red, accent_color.green, accent_color.blue, alpha);
            } else if (hovered) {
                cr.set_source_rgba (
                    double.min(color.red * 1.2, 1.0),
                    double.min(color.green * 1.2, 1.0),
                    double.min(color.blue * 1.2, 1.0),
                    alpha
                );
            } else {
                cr.set_source_rgba (color.red, color.green, color.blue, alpha);
            }
            
            if (is_temporary) {
                cr.set_dash ({ 5, 5 }, 0);
            }
            
            cr.set_line_width (LINE_WIDTH);
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.move_to (x1, y1);
            cr.curve_to (cx1, cy1, cx2, cy2, x2, y2);
            cr.stroke ();
            
            cr.set_dash (null, 0);
            cr.restore ();
        }
        
        // Check if point is near curve
        public override bool contains_point (double px, double py) {
            if (source_port == null) return false;
            if (!is_temporary && target_port == null) return false;
            
            double x1, y1, x2, y2, cx1, cy1, cx2, cy2;
            calculate_geometry (out x1, out y1, out cx1, out cy1, out cx2, out cy2, out x2, out y2);
            
            // Sample the bezier curve and check distance
            double min_dist = double.MAX;
            
            for (double t = 0.0; t <= 1.0; t += 0.02) {
                double mt = 1.0 - t;
                double mt2 = mt * mt;
                double mt3 = mt2 * mt;
                double t2 = t * t;
                double t3 = t2 * t;
                
                double bx = mt3 * x1 + 3.0 * mt2 * t * cx1 + 3.0 * mt * t2 * cx2 + t3 * x2;
                double by = mt3 * y1 + 3.0 * mt2 * t * cy1 + 3.0 * mt * t2 * cy2 + t3 * y2;
                
                double dx = px - bx;
                double dy = py - by;
                double dist = Math.sqrt (dx * dx + dy * dy);
                
                if (dist < min_dist) {
                    min_dist = dist;
                }
            }
            
            return min_dist <= 10.0;
        }

        // Check intersection with rect
        public bool intersects_rect (double rx1, double ry1, double rx2, double ry2) {
            if (source_port == null) return false;
            if (!is_temporary && target_port == null) return false;
            
            double x1, y1, x2, y2, cx1, cy1, cx2, cy2;
            calculate_geometry (out x1, out y1, out cx1, out cy1, out cx2, out cy2, out x2, out y2);
            
            // Normalize rect coordinates
            double r_min_x = double.min(rx1, rx2);
            double r_max_x = double.max(rx1, rx2);
            double r_min_y = double.min(ry1, ry2);
            double r_max_y = double.max(ry1, ry2);
            
            // Sample the bezier curve
            for (double t = 0.0; t <= 1.0; t += 0.02) {
                double mt = 1.0 - t;
                double mt2 = mt * mt;
                double mt3 = mt2 * mt;
                double t2 = t * t;
                double t3 = t2 * t;
                
                double bx = mt3 * x1 + 3.0 * mt2 * t * cx1 + 3.0 * mt * t2 * cx2 + t3 * x2;
                double by = mt3 * y1 + 3.0 * mt2 * t * cy1 + 3.0 * mt * t2 * cy2 + t3 * y2;
                
                if (bx >= r_min_x && bx <= r_max_x && by >= r_min_y && by <= r_max_y) {
                    return true;
                }
            }
            
            return false;
        }
        
        // Update path
        public void update_path () {
            // Trigger redraw - geometry is calculated in draw()
            // Canvas will redraw this item on next frame
        }
        
        // Disconnect ports
        public new void disconnect () {
            if (source_port != null) {
                source_port = null;
            }
            
            if (target_port != null) {
                target_port = null;
            }
        }
        
        // Port ID accessors for serialization
        public uint source_port_id {
            get { return source_port != null ? source_port.port_id : 0; }
        }
        
        public uint target_port_id {
            get { return target_port != null ? target_port.port_id : 0; }
        }
    }
}