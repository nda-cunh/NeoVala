public delegate bool Predicate<G> (G g);
public delegate A MapFunc<A,G> (owned G g);

public interface Traversable<G> {
	public abstract Iterator<G> iterator ();

	public virtual Iterator<G> filter (owned Predicate<G> pred) {
		return new FilterIterator<G> (iterator (), (owned) pred);
	}

	public virtual Iterator<A> map<A> (owned MapFunc<A,G> func) {
		return new MapIterator<A,G> (iterator (), (owned) func);
	}
}

public interface Iterator<G> : Traversable<G> {
	public abstract bool next ();
	public abstract G get ();
}

public class Counter : Iterator<int>, Traversable<int> {
	private int current;
	private int limit;

	public Counter (int limit) {
		this.current = 0;
		this.limit = limit;
	}

	public bool next () {
		this.current++;
		return this.current <= this.limit;
	}

	public int get () {
		return this.current;
	}

	public Iterator<int> iterator () {
		return this;
	}
}

public class FilterIterator<G> : Iterator<G>, Traversable<G> {
	private Iterator<G> it;
	private Predicate<G> pred;
	private G next_value;

	public FilterIterator (Iterator<G> it, owned Predicate<G> pred) {
		this.it = it;
		this.pred = (owned) pred;
	}

	public bool next () {
		while (it.next ()) {
			G value = it.get ();
			if (pred (value)) {
				this.next_value = value;
				return true;
			}
		}
		return false;
	}

	public G get () {
		return this.next_value;
	}

	public Iterator<G> iterator () {
		return this;
	}
}

public class MapIterator<A,G> : Iterator<A>, Traversable<A> {
	private Iterator<G> it;
	private MapFunc<A,G> func;
	private A next_value;

	public MapIterator (Iterator<G> it, owned MapFunc<A,G> func) {
		this.it = it;
		this.func = (owned) func;
	}

	public bool next () {
		if (it.next ()) {
			G value = it.get ();
			this.next_value = func ((owned) value);
			return true;
		}
		return false;
	}

	public A get () {
		return this.next_value;
	}

	public Iterator<A> iterator () {
		return this;
	}
}

void main () {
	Traversable<int> counter = new Counter (6);
	var evens = counter.filter ((v) => v % 2 == 0);

	evens.next ();
	assert (evens.get () == 2);
	evens.next ();
	assert (evens.get () == 4);
	evens.next ();
	assert (evens.get () == 6);
	assert (!evens.next ());

	// chained: the second filter dispatches through the first one's fat pointer
	var chained = new Counter (9).filter ((v) => v % 2 == 1).filter ((v) => v != 5);
	assert (chained.next () && chained.get () == 1);
	assert (chained.next () && chained.get () == 3);
	assert (chained.next () && chained.get () == 7);
	assert (chained.next () && chained.get () == 9);
	assert (!chained.next ());

	// a generic method on a generic interface: its own descriptor follows G's
	var mapped = new Counter (3).map<string> ((v) => "<%d>".printf (v));
	assert (mapped.next () && mapped.get () == "<1>");
	assert (mapped.next () && mapped.get () == "<2>");
	assert (mapped.next () && mapped.get () == "<3>");
	assert (!mapped.next ());
}
