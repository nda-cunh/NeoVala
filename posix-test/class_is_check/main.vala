class Animal { public Animal () {} }
class Dog : Animal { public Dog () {} }
class Cat : Animal { public Cat () {} }
int main () {
	Animal a = new Dog ();
	if (!(a is Dog)) return 1;
	if (a is Cat) return 2;
	if (!(a is Animal)) return 3;
	Animal b = new Cat ();
	if (b is Dog) return 4;
	if (!(b is Cat)) return 5;
	return 0;
}
