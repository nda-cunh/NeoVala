public class Node { public int v; }

void main () {
	var n = new Node ();
	weak Node w = n;
	assert (w.v == 0);
}
