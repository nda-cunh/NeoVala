errordomain Posix_error {
    FOO,
}

void function() throws Posix_error {
    throw new Posix_error.FOO("An error occurred");
}

void main() {
    try {
        string contents;
        GLib.FileUtils.get_contents("Makefile", out contents);
        function();
    }
    catch (Posix_error e) {
		assert (true);
    }
	catch (GLib.Error e) {
		assert (false);
	}
}
