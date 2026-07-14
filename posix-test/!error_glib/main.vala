errordomain MyError { BOOM }

void may_fail () throws MyError {
	throw new MyError.BOOM ("supra");
}

string read_it (string path) throws GLib.FileError {
	string s;
	GLib.FileUtils.get_contents (path, out s);
	return s;
}

void wrap () throws MyError {
	try {
		read_it ("/nonexistent/path");
	} catch (GLib.FileError e) {
		throw new MyError.BOOM ("wrapped");
	}
}

void main () {
	try {
		may_fail ();
	} catch (MyError e) {
		print ("vala: %s\n", e.message);
	}

	try {
		read_it ("/nonexistent/path");
	} catch (GLib.FileError e) {
		print ("glib domain: caught\n");
	}

	try {
		read_it ("/nonexistent/path");
	} catch (GLib.Error e) {
		print ("glib base: caught\n");
	}

	try {
		wrap ();
	} catch (MyError e) {
		print ("vala: %s\n", e.message);
	}
}
