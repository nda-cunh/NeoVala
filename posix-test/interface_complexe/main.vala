public interface Iterator<G> {
	public abstract bool next ();
	public abstract G get ();
}

public interface Iterable<G> {
	public abstract Iterator<G> iterator ();
}

public class List<G> : Iterable<G> {
	private G data;
	private List<G>? next_node; // Renommé pour éviter la confusion avec la méthode next()

	public List (G data) {
		this.data = data;
		this.next_node = null;
	}

	private class _ListIterator<G> : global::Iterator<G> {
		private unowned List<G>? current;
		private bool started;

		public _ListIterator (List<G> list) {
			this.current = list;
			this.started = false;
		}

		public bool next () {
			if (!started) {
				started = true;
				return this.current != null;
			}
			
			if (this.current != null) {
				this.current = this.current.next_node;
			}
			
			return this.current != null;
		}

		public G get () { 
			return ((!)current).data; 
		}
	}

	public Iterator<G> iterator () {
		return new _ListIterator<G> (this);
	}

	public void append (G data) {
		if (this.next_node == null) {
			this.next_node = new List<G> (data);
		} else {
			this.next_node.append (data);
		}
	}
}

void main() {
	var list = new List<int> (12);
	list.append (42);
	list.append (84);

	var it = list.iterator ();
	it.next ();
	assert (it.get () == 12);
	it.next ();
	assert (it.get () == 42);
	it.next ();
	assert (it.get () == 84);
}
