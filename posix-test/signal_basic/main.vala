public class Button {
	public signal void clicked (int x);
}

int total = 0;

void on_click (Button b, int x) {
	total += x;
}

void main () {
	var b = new Button ();
	b.clicked.connect (on_click);
	b.clicked (10);
	b.clicked (5);
	assert (total == 15);

	b.clicked.disconnect (on_click);
	b.clicked (100);
	assert (total == 15);
}
