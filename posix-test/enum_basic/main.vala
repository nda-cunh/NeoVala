enum Color {
	RED,
	GREEN,
	BLUE;

	public string label() {
		switch (this) {
			case RED: return "red";
			case GREEN: return "green";
			default: return "blue";
		}
	}
}

void main() {
	Color c = Color.GREEN;
	assert(c == Color.GREEN);
	assert(c != Color.RED);
	assert(c.label() == "green");
	assert(Color.BLUE.label() == "blue");
	assert((int)Color.BLUE == 2);
}
