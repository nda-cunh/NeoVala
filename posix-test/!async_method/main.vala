public class Adder {
	public int base_val;
	public Adder (int b) { this.base_val = b; }
	public async int add (int x) {
		int y = yield step (x);
		return this.base_val + y;
	}
	async int step (int x) { return x * 10; }
}

int result = 0;
Adder a;

void main () {
	a = new Adder (5);
	a.add.begin (3, (s, r) => {
		result = a.add.end (r);
	});
	if (result != 35)
		Posix.exit (1);
}
