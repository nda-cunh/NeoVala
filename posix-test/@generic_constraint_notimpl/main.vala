interface Drawable {
	public abstract void draw ();
}
void render<G : Drawable> (G g) {
	g.draw ();
}
void main () {
	render (42);
}
