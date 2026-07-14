public class Foo {
	public int prop { get; set; }
}


void main()
{
	var a = new Foo();
	a.prop = 42;
	assert(a.prop == 42);
}
