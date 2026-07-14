// valac main.vala Dog.vala Animal.vala

void main () {
	var d = new Dog ("Rex", 3, "Labrador");
	d.set_weight (12.5);
	assert (d.get_weight () == 12.5);
	assert (d.name == "Rex");
	assert (d.get_age() == 3);
}
