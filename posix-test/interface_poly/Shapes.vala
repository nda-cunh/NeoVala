public class Circle : IShape {
	public double r;

	public Circle (double r) {
		this.r = r;
	}

	public double area () {
		return 3.14159 * this.r * this.r;
	}

	public string name () {
		return "circle";
	}
}

public class Square : IShape {
	public double side;

	public Square (double side) {
		this.side = side;
	}

	public double area () {
		return this.side * this.side;
	}

	public string name () {
		return "square";
	}
}
