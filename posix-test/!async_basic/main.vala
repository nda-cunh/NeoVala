int result = 0;

async int compute (int x) {
	return x * 2;
}

void main () {
	compute.begin (21, (source, res) => {
		result = compute.end (res);
	});

	if (result != 42)
		Posix.exit (1);
}
