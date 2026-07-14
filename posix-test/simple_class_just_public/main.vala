class Foo {
	private int a = 42;
	public void test(){
		assert(a == 42);
	}
}

void main() {
	var foo = new Foo();
	foo.test();
}
