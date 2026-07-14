public class Dog : IGreeter {
	public string name;

	public Dog (string name) {
		this.name = name;
	}

	public string greet () {
		return "Woof";
	}

	public int priority () {
		return 7;
	}
}
