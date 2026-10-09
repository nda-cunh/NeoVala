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

async void run (Tracked n) {
	weakref Tracked? w = n;
	Idle.add (run.callback);
	yield;
	assert (w != null);
}

void main () {
	var loop = new MainLoop ();
	var n = new Tracked ();
	run.begin (n, (obj, res) => {
		run.end (res);
		loop.quit ();
	});
	loop.run ();
	assert (Tracked.registered == 0);
	check_balanced ();
}
