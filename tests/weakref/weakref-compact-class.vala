[Compact]
class Node {
	public string name;

	public void** slots[4];
	public int n_slots = 0;

	public Node (string name) {
		this.name = name;
	}

	~Node () {
		for (int i = 0; i < n_slots; i++) {
			if (slots[i] != null) {
				*slots[i] = null;
			}
		}
	}

	public void add_weak_pointer (void** location) {
		assert (n_slots < 4);
		slots[n_slots++] = location;
	}

	public void remove_weak_pointer (void** location) {
		for (int i = 0; i < n_slots; i++) {
			if (slots[i] == location) {
				slots[i] = null;
			}
		}
	}
}

class Holder {
	public weakref Node? target;
}

void test_local () {
	var n = new Node ("local");
	weakref Node? w = n;

	assert (w != null);
	assert (w.name == "local");

	n = null;
	assert (w == null);
}

void test_field () {
	var holder = new Holder ();
	var n = new Node ("field");

	holder.target = n;
	assert (holder.target != null);
	assert (holder.target.name == "field");

	n = null;
	assert (holder.target == null);
}

void test_field_finalize () {
	var n = new Node ("finalize");

	{
		var holder = new Holder ();
		holder.target = n;
		assert (holder.target != null);
		n = null;
		assert (holder.target == null);
	}
}

void main () {
	test_local ();
	test_field ();
	test_field_finalize ();
}
