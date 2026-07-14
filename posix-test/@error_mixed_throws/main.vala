errordomain MyError { BOOM }

void nope () throws MyError, GLib.FileError {
	throw new MyError.BOOM ("x");
}

void main () {
}
