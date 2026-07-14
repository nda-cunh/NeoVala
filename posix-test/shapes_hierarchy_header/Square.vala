public class Square : Rectangle {
	public Square (double s) {
		base (s, s);
		this.name = "Square";
	}
	public override string describe () {
		return "Square side=%g area=%g".printf (this.w, this.area ());
	}
}
