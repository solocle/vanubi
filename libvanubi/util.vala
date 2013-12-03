/*
 *  Copyright © 2011-2013 Luca Bruno
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

namespace Vanubi {
	public delegate G TaskFunc<G> (Cancellable cancellable) throws Error;

	public async G run_in_thread<G> (owned TaskFunc<G> func, Cancellable cancellable) throws Error {
		SourceFunc resume = run_in_thread.callback;
		Error err = null;
		G result = null;
		new Thread<void*> (null, () => {
				try {
					result = func (cancellable);
				} catch (Error e) {
					err = e;
				}
				Idle.add ((owned) resume);
				return null;
			});
		yield;
		if (err != null) {
			throw err;
		}
		cancellable.set_error_if_cancelled ();
		return result;
	}
	
	public async uint8[] read_all_async (InputStream is, Cancellable? cancellable = null) throws Error {
		uint8[] res = new uint8[1024];
		ssize_t offset = 0;
		ssize_t read = 0;
		while (true) {
			if (read > 512) {
				res.resize (res.length+1024);
			}
			unowned uint8[] buffer = (uint8[])(((uint8*)res)+offset);
			buffer.length = (int)(res.length-offset);
			read = yield is.read_async (buffer, Priority.DEFAULT, cancellable);
			if (read == 0) {
				return res;
			}
			offset += read;
		}
	}
	
	public async uint8[] execute_command_async (File? base_file, string command_line, uint8[]? input = null, Cancellable? cancellable = null) throws Error {
		string[] argv;
		Shell.parse_argv (command_line, out argv);
		int stdin, stdout;
		Process.spawn_async_with_pipes (get_base_directory (base_file), argv, null, SpawnFlags.SEARCH_PATH|SpawnFlags.FILE_AND_ARGV_ZERO, null, null, out stdin, out stdout, null);
		
		var os = new UnixOutputStream (stdin, true);
		yield os.write_async (input, Priority.DEFAULT, cancellable);
		os.close ();
		
		var is = new UnixInputStream (stdout, true);
		var res = yield read_all_async (is, cancellable);
		is.close ();
		return res;
	}
}