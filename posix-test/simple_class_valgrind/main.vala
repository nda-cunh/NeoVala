public class String {
	private string str;
	public String (owned string str) {
		this.str = str;
	}
	public void test() {
		assert(str == "Hello, World!");
	}

}

void main() {
	var str = new String("Hello, World!");
	str.test();
}
