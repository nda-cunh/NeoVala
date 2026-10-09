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

int early_return (Tracked n, bool flag) {
	weakref Tracked? w = n;
	if (flag) {
		return 1;
	}
	return w != null ? 2 : 3;
}

void loop_break_continue (Tracked n) {
	for (int i = 0; i < 6; i++) {
		weakref Tracked? w = n;
		if (i == 1) {
			continue;
		}
		if (i == 4) {
			break;
		}
		assert (w != null);
	}
}

void try_finally (Tracked n) {
	try {
		weakref Tracked? w = n;
		assert (w != null);
		throw new IOError.FAILED ("x");
	} catch (IOError e) {
		weakref Tracked? w2 = n;
		assert (w2 != null);
	} finally {
		weakref Tracked? w3 = n;
		assert (w3 != null);
	}
}

void main () {
	var n = new Tracked ();
	assert (early_return (n, true) == 1);
	assert (early_return (n, false) == 2);
	loop_break_continue (n);
	try_finally (n);
	assert (Tracked.registered == 0);
	check_balanced ();
}
