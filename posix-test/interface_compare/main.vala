public interface IFoo {
	public abstract void bar ();
}

public int TestID = 0;

public class Foo : IFoo {
	public Foo (){
		
	}
	public void bar () {
		TestID = 42;
	}
	~Foo (){

	}
}

void main() {
	var foo = new Foo ();

	if (foo is IFoo) {
		foo.bar ();
		assert(TestID == 42);
	} else {
		assert(false);
	}
}
