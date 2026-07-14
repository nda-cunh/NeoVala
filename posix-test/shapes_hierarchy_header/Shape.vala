public abstract class Shape {
	public string name;
	protected Shape (string name) { this.name = name; }
	public abstract double area ();
	public virtual string describe () {
		return "%s area=%g".printf (this.name, this.area ());
	}
}
