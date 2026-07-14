public class Animal {
	public string name;
	protected int age;
	private double weight;

	public Animal (string name, int age) {
		this.name = name;
		this.age = age;
		this.weight = 0.0;
	}

	public int get_age () {
		return this.age;
	}
	
	public virtual string speak () {
		return "...";
	}

	public void set_weight (double w) {
		this.weight = w;
	}

	public double get_weight () {
		return this.weight;
	}
}

public class Dog : Animal {
	public string breed;

	public Dog (string name, int age, string breed) {
		base (name, age);
		this.breed = breed;
	}

	public override string speak () {
		return "Woof";
	}
}
