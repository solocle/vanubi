/*
 *  Copyright © 2011-2014 Luca Bruno
 *
 *  This file is part of Vanubi.
 *
 *  Vanubi is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Vanubi is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Vanubi.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

namespace Vanubi.UI {
	class HelpBar : EntryBar {
		public enum Type {
			COMMAND,
			LANGUAGE
		}

		unowned State state;
		CompletionBox completion_box;
		Type type;
		
		Label shortcut_label;
		bool capturing = false;
		Key[] captured_keys = null;
		uint capture_timeout = 0;
		string changing_command = null;

		public HelpBar (State state, Type type) {
			this.state = state;
			this.type = type;
			completion_box = new CompletionBox (state, type);
			attach_next_to (completion_box, entry, PositionType.TOP, 1, 1);
			
			if (type == Type.COMMAND) {
				shortcut_label = new Label ("<b>C-r = reset shortcut     C-c = modify shortcut</b>");
				shortcut_label.use_markup = true;
				shortcut_label.expand = false;
				attach_next_to (shortcut_label, entry, PositionType.BOTTOM, 1, 1);
			}
			
			show_all ();
			search ("");
		}

		protected override void on_changed () {
			base.on_changed ();
			var text = entry.get_text ();
			search (text);
		}

		void search (string query) {
			List<SearchResultItem> result;
			if (type == Type.COMMAND) {
				result = state.command_index.search (query, true);
			} else {
				result = state.lang_index.search (query, true);
			}
			completion_box.set_docs (result);
		}

		protected override void on_activate () {
			var command = completion_box.get_selected_command ();
			if (command != null) {
				activate (command);
			}
		}

		void restart_capture_timeout () {
			if (capture_timeout > 0) {
				Source.remove (capture_timeout);
			}
			
			// ugly :P
			var keystr = keys_to_string (captured_keys);
			shortcut_label.set_markup (@"<b>saving as &lt;$keystr&gt; in 3 seconds</b>");
			capture_timeout = Timeout.add_seconds (1, () => {
					shortcut_label.set_markup (@"<b>saving as &lt;$keystr&gt; in 2 seconds</b>");
					capture_timeout = Timeout.add_seconds (1, () => {
							shortcut_label.set_markup (@"<b>saving as &lt;$keystr&gt; in 1 second</b>");
							capture_timeout = Timeout.add_seconds (1, () => {
									save_shortcut (changing_command);
									capturing = false;
									
									
									return false;
							});
							return false;
					});
					return false;
			});
		}
		
		void save_shortcut (string cmd) {
			var keys = (owned) captured_keys;
			if (keys.length == 0) {
				shortcut_label.set_markup ("<b>cleared shortcut for %s</b>".printf (cmd));
				state.global_keys.remove_binding (cmd);
				state.config.remove_shortcut (cmd);
			} else {
				var str = keys_to_string (keys);
				shortcut_label.set_markup ("<b>%s saved as %s</b>".printf (cmd, str));
				state.global_keys.rebind_command (keys, cmd);
				state.config.set_shortcut (changing_command, keys_to_string (keys));
			}
			
			if (capture_timeout > 0) {
				Source.remove (capture_timeout);
			}
			capture_timeout = Timeout.add_seconds (2, () => {
					shortcut_label.set_markup ("<b>C-r = reset shortcut     C-c = modify shortcut</b>");
					capture_timeout = 0;
					captured_keys = null;
					return false;
			});
			
			state.config.save ();
			// refresh
			search (entry.get_text ());
		}

		void reset_shortcut (string cmd) {
			unowned Key[] keys = state.global_keys.get_default_shortcut (cmd);
			if (keys.length == 0) {
				state.global_keys.remove_binding (cmd);
				state.config.remove_shortcut (cmd);
			} else {
				state.global_keys.rebind_command (keys, cmd);
				state.config.set_shortcut (changing_command, keys_to_string (keys));
			}
			shortcut_label.set_markup ("<b>reset shortcut for %s</b>".printf (cmd));
			
			if (capture_timeout > 0) {
				Source.remove (capture_timeout);
			}
			capture_timeout = Timeout.add_seconds (2, () => {
					shortcut_label.set_markup ("<b>C-r = reset shortcut     C-c = modify shortcut</b>");
					capture_timeout = 0;
					captured_keys = null;
					return false;
			});
			
			state.config.save ();
			// refresh
			search (entry.get_text ());
		}
		
		protected override bool on_key_press_event (Gdk.EventKey e) {
			var modifiers = e.state & (Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK);
			if (capturing) {
				if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && modifiers == Gdk.ModifierType.CONTROL_MASK)) {
					state.status.set ("Cannot bind Escape or C-g", "help", Status.Type.ERROR);
					capturing = false;
					Source.remove (capture_timeout);
					capture_timeout = 0;
				} else if (e.keyval in KeyHandler.skip_keyvals) {
					// skip
				} else {
					captured_keys += Key (e.keyval, modifiers);
					restart_capture_timeout ();
				}
				return true;
			}
			
			if (e.keyval == Gdk.Key.c && modifiers == Gdk.ModifierType.CONTROL_MASK) {
				var cmd = completion_box.get_selected_command ();
				if (cmd == null) {
					state.status.set ("No command selected", "help");
				} else {
					changing_command = cmd;
					captured_keys = null;
					capturing = true;
					restart_capture_timeout ();
				}
				return true;
			}

			if (e.keyval == Gdk.Key.r && modifiers == Gdk.ModifierType.CONTROL_MASK) {
				var cmd = completion_box.get_selected_command ();
				if (cmd == null) {
					state.status.set ("No command selected", "help");
				} else {				
					reset_shortcut (cmd);
				}
			}
			
			if (e.keyval == Gdk.Key.Up || e.keyval == Gdk.Key.Down) {
				completion_box.view.grab_focus ();
				var res = completion_box.view.key_press_event (e);
				entry.grab_focus ();
				return res;
			}
			return base.on_key_press_event (e);
		}

		class CompletionBox : Grid {
			Gtk.ListStore store;
			public TreeView view;
			unowned State state;
			HelpBar.Type type;

			public CompletionBox (State state, Type type) {
				this.state = state;
				this.type = type;
				store = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (string));
				view = new TreeView.with_model (store);			
				view.headers_visible = false;
				var sel = view.get_selection ();
				sel.mode = SelectionMode.BROWSE;

				Gtk.CellRendererText cell = new Gtk.CellRendererText ();
				if (type == Type.COMMAND) {
					view.insert_column_with_attributes (-1, "Name", cell, "text", 0);
					view.insert_column_with_attributes (-1, "Key", cell, "text", 1);
					view.insert_column_with_attributes (-1, "Description", cell, "text", 2);
				} else {
					view.insert_column_with_attributes (-1, "Id", cell, "text", 0);
					view.insert_column_with_attributes (-1, "Name", cell, "text", 1);
				}

				var sw = new ScrolledWindow (null, null);
				sw.expand = true;
				sw.add (view);
				add (sw);
			}

			public void set_docs (List<SearchResultItem> items) {
				store.clear ();
				Gtk.TreeIter iter;
				foreach (var item in items) {
					store.append (out iter);
					var doc = (StringSearchDocument) item.doc;
					if (type == Type.COMMAND) {
						var keys = state.global_keys.get_binding (doc.name);
						string keystring = "";
						if (keys != null) {
							keystring = keys_to_string (keys);
						}
						store.set (iter, 0, doc.name, 1, keystring, 2, doc.fields[0]);
					} else {
						store.set (iter, 0, doc.name, 1, doc.fields[0]);
					}
				}
				// select first item
				if (store.get_iter_first (out iter)) {
					var sel = view.get_selection ();
					sel.select_iter (iter);
				}
			}

			public string? get_selected_command () {
				var sel = view.get_selection ();
				TreeIter iter;
				if (sel.get_selected (null, out iter)) {
					string val;
					store.get (iter, 0, out val);
					return val;
				}
				return null;
			}
		}
	}
}