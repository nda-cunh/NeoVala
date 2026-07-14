// valac main.vala

public class Foo {
	public uint8[] data;
	public Foo () {
		this.data = new uint8[10];
	}
	~Foo () {

	}
}

void main() {
	var foo = new Foo();
	int a = foo.data.length;
	assert(a == 10);
}
