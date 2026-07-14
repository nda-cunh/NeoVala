errordomain MyError { BOOM }

void may_fail (bool b) throws MyError {
	if (b) throw new MyError.BOOM ("supra");
}

string read_it (string p) throws GLib.FileError {
	string s;
	GLib.FileUtils.get_contents (p, out s);
	return s;
}

void run (bool b, string path) {
	try {
		may_fail (b);
		read_it (path);
		print ("no error\n");
	} catch (MyError e) {
		print ("caught vala: %s\n", e.message);
	} catch (GLib.FileError e) {
		print ("caught glib\n");
	} finally {
		print ("  finally\n");
	}
}

void inner (out string res) throws GLib.FileError {
	res = "none";
	try {
		may_fail (true);
	} catch (MyError e) {
		res = read_it ("/etc/hostname");
	}
}

void main () {
	run (true, "/etc/hostname");
	run (false, "/nonexistent/path");
	run (false, "/etc/hostname");

	try {
		string r;
		inner (out r);
		print ("inner ok\n");
	} catch (GLib.FileError e) {
		print ("inner glib\n");
	}
}
