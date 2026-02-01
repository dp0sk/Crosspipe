namespace Crosspipe.Canvas {

    // Canvas item base
    public abstract class CanvasItem : Object {
        
        // Position
        protected double _x = 0;
        protected double _y = 0;
        
        public double x { 
            get { return _x; } 
            set { 
                if (_x != value) {
                    _x = value;
                    on_geometry_changed ();
                }
            } 
        }
        
        public double y { 
            get { return _y; } 
            set { 
                if (_y != value) {
                    _y = value;
                    on_geometry_changed ();
                }
            } 
        }
        
        // Size
        protected double _width = 100;
        protected double _height = 50;
        
        public double width { 
            get { return _width; } 
            set { 
                if (_width != value) {
                    _width = value;
                    on_geometry_changed ();
                }
            } 
        }
        
        public double height { 
            get { return _height; } 
            set { 
                if (_height != value) {
                    _height = value;
                    on_geometry_changed ();
                }
            } 
        }

        // Called on geometry change
        protected virtual void on_geometry_changed () {
            if (this.visible) {}
        }
        
        // State
        public bool selected { get; set; default = false; }
        public bool highlighted { get; set; default = false; }
        public bool hovered { get; set; default = false; }
        public bool visible { get; set; default = true; }
        
        // Draw item
        public virtual void draw (Cairo.Context cr, Gtk.StyleContext ctx) {
            if (cr == null) return;
        }
        
        // Point hit test
        public virtual bool contains_point (double px, double py) {
            return px >= x && px <= x + width &&
                   py >= y && py <= y + height;
        }
        
        // Translate item
        public virtual void move_by (double dx, double dy) {
            x += dx;
            y += dy;
        }
    }
    
    // Drawing helpers
    namespace DrawingHelpers {
        public void rounded_rectangle (Cairo.Context cr, 
                                              double x, double y, 
                                              double width, double height,
                                              double radius) {
            double degrees = Math.PI / 180.0;
            
            cr.new_sub_path ();
            cr.arc (x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees);
            cr.arc (x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees);
            cr.arc (x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees);
            cr.arc (x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
            cr.close_path ();
        }
        
        public void draw_shadow (Cairo.Context cr,
                                        double x, double y,
                                        double width, double height,
                                        double radius, double offset = 3) {
            cr.set_source_rgba (0, 0, 0, 0.2);
            rounded_rectangle (cr, x + offset, y + offset, width, height, radius);
            cr.fill ();
        }
    }
}
