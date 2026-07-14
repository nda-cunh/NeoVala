public class Cat : IGreeter {
	public string name;

	public Cat (string name) {
		this.name = name;
	}

	public string greet () {
		return "Miaou";
	}

	public int priority () {
		return 28;
	}
}
