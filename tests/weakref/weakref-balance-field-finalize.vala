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

class Holder {
	public weakref Tracked? target;
}

void main () {
	var n = new Tracked ();
	{
		var h = new Holder ();
		h.target = n;
		assert (Tracked.registered == 1);
	}
	assert (Tracked.registered == 0);
	check_balanced ();
}
