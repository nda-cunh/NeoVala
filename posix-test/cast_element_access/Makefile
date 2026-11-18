run:
	@$(VALAC) main.vala -o main 2> valac.log; cat valac.log
	@! grep -q CRITICAL valac.log
	@./main
