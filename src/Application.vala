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
                { "shortcuts", this.on_shortcuts_action },
            };
            this.add_action_entries (action_entries, this);
            
            // Keyboard shortcuts
            this.set_accels_for_action ("app.shortcuts", { "F1", "<Ctrl>question" });
            this.set_accels_for_action ("app.quit", { "<Ctrl>q" });
            this.set_accels_for_action ("win.undo", { "<Ctrl>z" });
            this.set_accels_for_action ("win.redo", { "<Ctrl>y", "<Ctrl><Shift>z" });
            this.set_accels_for_action ("win.zoom-in", { "<Ctrl>plus", "<Ctrl>equal" });
            this.set_accels_for_action ("win.zoom-out", { "<Ctrl>minus" });
            this.set_accels_for_action ("win.zoom-reset", { "<Ctrl>0" });
            this.set_accels_for_action ("win.zoom-fit", { "<Ctrl>f" });
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

        private void on_shortcuts_action () {
            var dialog = new Adw.ShortcutsDialog ();
            
            // General Section
            var general_section = new Adw.ShortcutsSection ("General");
            general_section.add (new Adw.ShortcutsItem ("Quit", "<Ctrl>q"));
            general_section.add (new Adw.ShortcutsItem ("Refresh Graph", "F5"));
            general_section.add (new Adw.ShortcutsItem ("Refresh Graph (Alt)", "<Ctrl>r"));
            dialog.add (general_section);
            
            // View Section
            var view_section = new Adw.ShortcutsSection ("View");
            view_section.add (new Adw.ShortcutsItem ("Zoom In", "<Ctrl>plus"));
            view_section.add (new Adw.ShortcutsItem ("Zoom Out", "<Ctrl>minus"));
            view_section.add (new Adw.ShortcutsItem ("Reset Zoom", "<Ctrl>0"));
            view_section.add (new Adw.ShortcutsItem ("Fit to Content", "<Ctrl>f"));
            dialog.add (view_section);
            
            // Editing Section
            var edit_section = new Adw.ShortcutsSection ("Editing");
            edit_section.add (new Adw.ShortcutsItem ("Undo", "<Ctrl>z"));
            edit_section.add (new Adw.ShortcutsItem ("Redo", "<Ctrl>y"));
            edit_section.add (new Adw.ShortcutsItem ("Select All", "<Ctrl>a"));
            edit_section.add (new Adw.ShortcutsItem ("Delete Selected", "Delete"));
            dialog.add (edit_section);
            
            dialog.present (main_window);
        }

        public static int main (string[] args) {
            var app = new Application ();
            return app.run (args);
        }
    }
}
