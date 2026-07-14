delegate string Producer ();

void main () {
	string prefix = "hello-";
	Producer p = () => {
		return prefix + "world";
	};
	string r = p ();
	if (r != "hello-world")
		Posix.exit (1);

	int outer = 1;
	Producer q = () => {
		int inner = outer + 1;
		Producer inner_op = () => {
			return "n=%d".printf (outer + inner);
		};
		return inner_op ();
	};
	if (q () != "n=3")
		Posix.exit (2);
}
