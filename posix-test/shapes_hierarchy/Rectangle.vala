public class Rectangle : Shape {
	protected double w;
	protected double h;
	public Rectangle (double w, double h) {
		base ("Rectangle");
		this.w = w;
		this.h = h;
	}
	public override double area () { return this.w * this.h; }
}
