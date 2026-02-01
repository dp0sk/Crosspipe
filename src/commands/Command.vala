namespace Crosspipe.Commands {

    public interface Command : Object {
        public abstract void execute ();
        public abstract void undo ();
        public abstract string get_label ();
    }

    public class CommandManager : Object {
        private Gee.Deque<Command> undo_stack;
        private Gee.Deque<Command> redo_stack;
        private const int MAX_STACK_SIZE = 50;

        public signal void changed ();

        public CommandManager () {
            undo_stack = new Gee.LinkedList<Command> ();
            redo_stack = new Gee.LinkedList<Command> ();
        }

        public void execute (Command command) {
            command.execute ();
            undo_stack.offer_head (command);
            redo_stack.clear ();

            if (undo_stack.size > MAX_STACK_SIZE) {
                undo_stack.poll_tail ();
            }
            changed ();
        }

        public void undo () {
            if (undo_stack.is_empty) return;

            var command = undo_stack.poll_head ();
            command.undo ();
            redo_stack.offer_head (command);
            changed ();
        }

        public void redo () {
            if (redo_stack.is_empty) return;

            var command = redo_stack.poll_head ();
            command.execute ();
            undo_stack.offer_head (command);
            changed ();
        }

        public bool can_undo {
            get { return !undo_stack.is_empty; }
        }

        public bool can_redo {
            get { return !redo_stack.is_empty; }
        }

        public string? undo_label {
            owned get { return undo_stack.is_empty ? null : undo_stack.peek_head ().get_label (); }
        }

        public string? redo_label {
            owned get { return redo_stack.is_empty ? null : redo_stack.peek_head ().get_label (); }
        }
    }

    public class ConnectCommand : Object, Command {
        private weak Canvas.GraphCanvas canvas;
        private uint source_id;
        private uint target_id;

        public ConnectCommand (Canvas.GraphCanvas canvas, uint source_id, uint target_id) {
            this.canvas = canvas;
            this.source_id = source_id;
            this.target_id = target_id;
        }

        public void execute () {
            canvas.add_connection (source_id, target_id);
        }

        public void undo () {
            canvas.remove_connection_by_ports (source_id, target_id);
        }

        public string get_label () {
            return "Connect Ports";
        }
    }
}
