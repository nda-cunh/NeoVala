public class Box {
	public int v;
	public Box (int v) { this.v = v; }
}

int? maybe (int v) { return v; }
Box? make (int v) { return new Box (v); }

void main () {
	// value type: if (x != null) narrows int? to int
	int? x = maybe (42);
	if (x != null) {
		int a = x;
		assert (a == 42);
	}

	// value type: early-return narrowing
	int? y = maybe (7);
	if (y == null) return;
	int b = y;
	assert (b == 42 - 35);

	// reference type: narrowing allows member access + assignment
	Box? box = make (9);
	if (box == null) return;
	assert (box.v == 9);
	unowned Box strong = box;
	assert (strong.v == 9);

	// conjunction
	int? p = maybe (1);
	int? q = maybe (2);
	if (p != null && q != null) {
		assert (p + q == 3);
	}

	print ("narrow OK\n");
}
