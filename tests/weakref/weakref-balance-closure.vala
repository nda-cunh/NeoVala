[Compact]
class Tracked {
	public static int registered = 0;
	public static int bad_removes = 0;

	public void** slots[8];
	public int n_slots = 0;

	public Tracked () {
	}

	~Tracked () {
		for (int i = 0; i < n_slots; i++) {
			if (slots[i] != null) {
				*slots[i] = null;
				registered--;
			}
		}
	}

	public void add_weak_pointer (void** location) {
		for (int i = 0; i < n_slots; i++) {
			if (slots[i] == null) {
				slots[i] = location;
				registered++;
				return;
			}
		}
		assert (n_slots < 8);
		slots[n_slots++] = location;
		registered++;
	}

	public void remove_weak_pointer (void** location) {
		for (int i = 0; i < n_slots; i++) {
			if (slots[i] == location) {
				slots[i] = null;
				registered--;
				return;
			}
		}
		bad_removes++;
	}
}

void check_balanced () {
	assert (Tracked.registered == 0);
	assert (Tracked.bad_removes == 0);
}

delegate int Getter ();

Getter make_getter (Tracked n) {
	weakref Tracked? w = n;
	return () => { return w != null ? 1 : 0; };
}

void main () {
	var n = new Tracked ();
	{
		var g = make_getter (n);
		assert (g () == 1);
	}
	assert (Tracked.registered == 0);
	n = null;
	check_balanced ();
}
