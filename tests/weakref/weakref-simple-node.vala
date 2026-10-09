int count = 0;

class Lst : Object {
	public int idx;

	public Lst (int idx) {
		this.idx = idx;
	}

	~Lst() {
		count++;
	}

	public void add (int idx) {
		unowned Lst? ptr = (!)this;
		while (ptr.next != null) {
			ptr = ptr.next;
		}
		ptr.next = new Lst(idx);
		ptr.next.prev = ptr;
	}

	public Lst? next = null;
	public weakref Lst prev = null;
}

void main () {
	var test = new Lst(0); 
	test.add(1);
	test.add(2);
	test.add(3);

	weakref Lst num_2 = test.next.next.next.prev;

	assert (num_2 != null);
	assert (num_2?.idx == 2);
	test = null;
	assert (num_2 == null);
	assert (count == 4);
}
