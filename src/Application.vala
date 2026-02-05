namespace Crosspipe {
    public class Application : Adw.Application {
        private Window? main_window = null;
        
        private static bool verbose = false;

        private const GLib.OptionEntry[] entries = {
            { "verbose", 'v', 0, GLib.OptionArg.NONE, ref verbose, "Enable verbose logging", null },
            { null }
        };

        public Application () {
            Object (
                application_id: Config.APP_ID,
                flags: ApplicationFlags.FLAGS_NONE
            );
            this.add_main_option_entries (entries);
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
        
        protected override int handle_local_options (GLib.VariantDict options) {
            if (options.contains ("verbose")) {
                verbose = true;
            }

            // Set up logging
            Log.set_writer_func ((level, fields) => {
                // If not verbose, ignore everything below WARNING
                if (!verbose && (level & (LogLevelFlags.LEVEL_DEBUG | LogLevelFlags.LEVEL_INFO | LogLevelFlags.LEVEL_MESSAGE)) != 0) {
                    return LogWriterOutput.HANDLED;
                }
                return Log.writer_default (level, fields);
            });

            if (verbose) {
                Environment.set_variable ("G_MESSAGES_DEBUG", "all", true);
            }

            return -1;
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
