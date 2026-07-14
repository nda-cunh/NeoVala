errordomain Posix_error {
    FOO,
}

void function() throws Posix_error {
    throw new Posix_error.FOO("An error occurred");
}

void main() {
    try {
        string contents;
        GLib.FileUtils.get_contents("CMAKE", out contents);
        function();
    }
    catch (Posix_error e) {
		assert (false);
    }
	catch (GLib.Error e) {
		assert (true);
	}
}
