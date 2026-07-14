// valac main.vala
public int NBR = 0;

class MyClass
{
	~MyClass () {
		NBR += 4;
	}

	public MyClass(int value)
	{
		NBR += 6;
	}

	public void myMethod()
	{
		NBR += 2;
	}
}

void main()
{
	{
		MyClass obj = new MyClass(10);
		assert(NBR == 6);
		obj.myMethod();

		assert(NBR == 8);
	}
	assert(NBR == 12);
}
