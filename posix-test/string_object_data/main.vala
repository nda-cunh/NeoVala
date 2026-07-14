public class String {
	private uint8[] data;

	public String (owned string str) {
		this.data = (uint8[])str;
	}

	public int length {
		get { return this.data.length; }
	}

	public unowned string to_string() {
		return (string)(this.data);
	}
}

void main() {
	new String("Hello, World!");
}
