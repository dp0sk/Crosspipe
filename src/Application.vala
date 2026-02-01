namespace Crosspipe {
    public class Application : Adw.Application {
        private Window? main_window = null;
        
        public Application () {
            Object (
                application_id: Config.APP_ID,
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }
        
        construct {
            ActionEntry[] action_entries = {
                { "quit", this.quit },
                { "about", this.on_about_action },
            };
            this.add_action_entries (action_entries, this);
            
            // Keyboard shortcuts
            this.set_accels_for_action ("app.quit", { "<Ctrl>q" });
            this.set_accels_for_action ("win.undo", { "<Ctrl>z" });
            this.set_accels_for_action ("win.redo", { "<Ctrl>y", "<Ctrl><Shift>z" });
            this.set_accels_for_action ("win.zoom-in", { "<Ctrl>plus", "<Ctrl>equal" });
            this.set_accels_for_action ("win.zoom-out", { "<Ctrl>minus" });
            this.set_accels_for_action ("win.zoom-reset", { "<Ctrl>0" });
            this.set_accels_for_action ("win.refresh", { "F5", "<Ctrl>r" });
        }
        
        protected override void activate () {
            if (main_window == null) {
                main_window = new Window (this);
            }
            main_window.present ();
        }
        
        private void on_about_action () {
            var dialog = new Adw.AboutDialog () {
                application_name = Config.APP_NAME,
                application_icon = Config.APP_ID,
                developer_name = "dp0sk",
                version = Config.APP_VERSION,
                developers = { "dp0sk" },
                copyright = "© 2026 dp0sk",
                license_type = Gtk.License.GPL_3_0,
                website = "https://github.com/dp0sk/crosspipe",
                issue_url = "https://github.com/dp0sk/crosspipe/issues",
            };
            dialog.add_credit_section ("Thanks to", { "rncbc aka Rui Nuno Capela for qpwgraph" });
            dialog.present (main_window);
        }

        public static int main (string[] args) {
            var app = new Application ();
            return app.run (args);
        }
    }
}
