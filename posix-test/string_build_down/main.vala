public class String {
	private uint8[] data;

	public String () {
		uint8[] src = {'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!', 0};
		this.data = src;
	}

	public int length {
		get { return this.data.length - 1; }
	}

	public unowned string to_string() {
		return (string)(this.data);
	}

	public void up () {
		for (int i = 0; i < this.length; i++) {
			char c = (char)this.data[i];
			if (c.is_alpha()) {
				this.data[i] = (uint8)c.to_upper();
			}
		}
	}
}

void main() {
	var str = new String();
	assert(str.length == 13);
	str.up();
	assert(str.to_string() == "HELLO, WORLD!");
}
