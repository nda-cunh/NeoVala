int? f () { return 42; }

void main () {
	int? x = f ();
	int a = (!) x;
	print ("%d\n", a);
}
