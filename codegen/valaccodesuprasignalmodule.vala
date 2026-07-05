/* valaccodesuprasignalmodule.vala
 *
 * GLib-free signals for the POSIX (supra) backend. A signal is a per-instance
 * singly-linked list of closures { callback, user_data, id }; connect prepends
 * a node and returns an id, disconnect removes by id, emit walks the list and
 * calls each closure with the (typed) signal arguments plus its user_data.
 * Split out of CCodeSupraModule; sits above it in the supra chain.
 */

using Vala;

public class Vala.CCodeSupraSignalModule : CCodeSupraModule {

	private string signal_field_cname (Signal sig) {
		return "__sig_%s".printf (sig.name);
	}

	private string signal_emit_func (Class cl, Signal sig) {
		return "%s_%s".printf (get_ccode_lower_case_name (cl), sig.name);
	}

	private void emit_supra_signal_closure_typedef (CCodeFile decl_space) {
		if (decl_space.add_declaration ("supra_closure")) {
			return;
		}
		decl_space.add_include ("stddef.h");
		decl_space.add_type_declaration (new CCodeIdentifier (
			"""typedef struct _supra_closure {
	void* callback;
	void* user_data;
	void (*destroy) (void*);
	unsigned long id;
	struct _supra_closure* next;
} supra_closure;"""));
	}

	private void emit_supra_signal_connect_fn () {
		if (!add_wrapper ("supra_signal_connect")) {
			return;
		}
		emit_supra_signal_closure_typedef (cfile);
		cfile.add_include ("stdlib.h");
		cfile.add_type_member_definition (new CCodeIdentifier (
			"""static unsigned long supra_signal_connect (supra_closure** head, void* callback, void* user_data, void (*destroy) (void*)) {
	static unsigned long counter = 0;
	supra_closure* c = (supra_closure*) calloc (1, sizeof (supra_closure));
	c->callback = callback;
	c->user_data = user_data;
	c->destroy = destroy;
	c->id = ++counter;
	c->next = *head;
	*head = c;
	return c->id;
}"""));
	}

	private void emit_supra_signal_disconnect_fn () {
		if (!add_wrapper ("supra_signal_disconnect")) {
			return;
		}
		emit_supra_signal_closure_typedef (cfile);
		cfile.add_include ("stdlib.h");
		cfile.add_type_member_definition (new CCodeIdentifier (
			"""static void supra_signal_disconnect (supra_closure** head, void* callback) {
	while (*head != NULL) {
		if ((*head)->callback == callback) {
			supra_closure* dead = *head;
			*head = dead->next;
			if (dead->destroy != NULL) {
				dead->destroy (dead->user_data);
			}
			free (dead);
			return;
		}
		head = &(*head)->next;
	}
}"""));
	}

	private void emit_supra_signal_clear_fn () {
		if (!add_wrapper ("supra_signal_clear")) {
			return;
		}
		emit_supra_signal_closure_typedef (cfile);
		cfile.add_include ("stdlib.h");
		cfile.add_type_member_definition (new CCodeIdentifier (
			"""static void supra_signal_clear (supra_closure** head) {
	while (*head != NULL) {
		supra_closure* dead = *head;
		*head = dead->next;
		if (dead->destroy != NULL) {
			dead->destroy (dead->user_data);
		}
		free (dead);
	}
}"""));
	}

	protected override void append_supra_signal_fields (Class cl, CCodeStruct instance_struct, CCodeFile decl_space) {
		var signals = cl.get_signals ();
		if (signals.size == 0) {
			return;
		}
		emit_supra_signal_closure_typedef (decl_space);
		foreach (Signal sig in signals) {
			instance_struct.add_field ("supra_closure*", signal_field_cname (sig));
		}
	}

	protected override void emit_supra_signal_init (Class cl) {
		foreach (Signal sig in cl.get_signals ()) {
			var field = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), signal_field_cname (sig));
			ccode.add_assignment (field, new CCodeConstant ("NULL"));
		}
	}

	protected override void emit_supra_signal_finalize (Class cl) {
		var signals = cl.get_signals ();
		if (signals.size == 0) {
			return;
		}
		emit_supra_signal_clear_fn ();
		foreach (Signal sig in signals) {
			var head = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
				new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), signal_field_cname (sig)));
			var call = new CCodeFunctionCall (new CCodeIdentifier ("supra_signal_clear"));
			call.add_argument (head);
			ccode.add_expression (call);
		}
	}

	public override void visit_signal (Signal sig) {
		unowned Class? cl = sig.parent_symbol as Class;
		if (context.profile != Profile.POSIX || cl == null || !cl.is_supraklass) {
			base.visit_signal (sig);
			return;
		}
		generate_supra_signal_emit (cl, sig);
	}

	private void generate_supra_signal_emit (Class cl, Signal sig) {
		string cname = get_ccode_name (cl);
		string emit_name = signal_emit_func (cl, sig);
		string ret = get_ccode_name (sig.return_type);
		bool has_ret = !(sig.return_type is VoidType);

		var params_decl = new StringBuilder ();
		var cast_params = new StringBuilder ();
		var call_args = new StringBuilder ();
		foreach (Parameter p in sig.get_parameters ()) {
			string ptype = get_ccode_name (p.variable_type);
			params_decl.append_printf (", %s %s", ptype, p.name);
			cast_params.append_printf (", %s", ptype);
			call_args.append_printf (", %s", p.name);
		}

		CCodeFile decl_space = cfile;
		if (context.header_filename != null && !cl.is_internal_symbol ()) {
			decl_space = header_file;
		}
		if (!decl_space.add_declaration (emit_name)) {
			decl_space.add_type_member_declaration (new CCodeIdentifier (
				"%s %s (%s* self%s);".printf (ret, emit_name, cname, params_decl.str)));
		}

		if (cfile.add_declaration ("%s__def".printf (emit_name))) {
			return;
		}

		var body = new StringBuilder ();
		body.append_printf ("%s %s (%s* self%s) {\n", ret, emit_name, cname, params_decl.str);
		if (has_ret) {
			body.append_printf ("\t%s __r = (%s) 0;\n", ret, ret);
		}
		body.append_printf ("\tfor (supra_closure* __c = self->%s; __c != NULL; __c = __c->next) {\n", signal_field_cname (sig));
		string cast = "(%s (*) (%s*%s, void*)) __c->callback".printf (ret, cname, cast_params.str);
		if (has_ret) {
			body.append_printf ("\t\t__r = (%s) (self%s, __c->user_data);\n", cast, call_args.str);
		} else {
			body.append_printf ("\t\t(%s) (self%s, __c->user_data);\n", cast, call_args.str);
		}
		body.append ("\t}\n");
		if (has_ret) {
			body.append ("\treturn __r;\n");
		}
		body.append ("}");
		cfile.add_type_member_definition (new CCodeIdentifier (body.str));
	}

	public override void visit_member_access (MemberAccess expr) {
		if (context.profile == Profile.POSIX && expr.symbol_reference is Signal
		    && !(expr.parent_node is MemberAccess)) {
			unowned Signal sig = (Signal) expr.symbol_reference;
			unowned Class? cl = sig.parent_symbol as Class;
			if (cl != null && cl.is_supraklass) {
				var ccall = new CCodeFunctionCall (new CCodeIdentifier (signal_emit_func (cl, sig)));
				ccall.add_argument (supra_signal_instance (cl, expr.inner));
				set_cvalue (expr, ccall);
				return;
			}
		}
		base.visit_member_access (expr);
	}

	public override void visit_method_call (MethodCall expr) {
		var mtype = expr.call.value_type as MethodType;
		if (context.profile == Profile.POSIX && mtype != null
		    && mtype.method_symbol.parent_symbol is Signal) {
			unowned Signal sig = (Signal) mtype.method_symbol.parent_symbol;
			unowned Class? cl = sig.parent_symbol as Class;
			if (cl != null && cl.is_supraklass) {
				emit_supra_signal_connection (expr, sig, cl, mtype.method_symbol.name);
				return;
			}
		}
		base.visit_method_call (expr);
	}

	private void emit_supra_signal_connection (MethodCall expr, Signal sig, Class cl, string op) {
		var signal_access = ((MemberAccess) expr.call).inner;
		var inst = supra_signal_instance (cl, ((MemberAccess) signal_access).inner);
		var head = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
			new CCodeMemberAccess.pointer (inst, signal_field_cname (sig)));

		var handler = expr.get_argument_list ().get (0);
		var cb = new CCodeCastExpression (get_ccodenode (handler), "void*");

		if (op == "disconnect") {
			// match by callback only, so the target is never re-owned here
			emit_supra_signal_disconnect_fn ();
			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("supra_signal_disconnect"));
			ccall.add_argument (head);
			ccall.add_argument (cb);
			ccode.add_expression (ccall);
			return;
		}

		var target = new CCodeCastExpression (get_delegate_target (handler) ?? new CCodeConstant ("NULL"), "void*");
		var destroy = get_delegate_target_destroy_notify (handler) ?? new CCodeConstant ("NULL");

		emit_supra_signal_connect_fn ();
		var connect_call = new CCodeFunctionCall (new CCodeIdentifier ("supra_signal_connect"));
		connect_call.add_argument (head);
		connect_call.add_argument (cb);
		connect_call.add_argument (target);
		connect_call.add_argument (new CCodeCastExpression (destroy, "void (*) (void*)"));

		if (expr.parent_node is ExpressionStatement) {
			ccode.add_expression (connect_call);
		} else {
			var temp = get_temp_variable (expr.value_type, true, expr);
			emit_temp_var (temp);
			ccode.add_assignment (get_variable_cexpression (temp.name), connect_call);
			set_cvalue (expr, get_variable_cexpression (temp.name));
		}
	}

	// The instance carrying the signal, cast to the class that declares it, so
	// self->__sig_x reaches the field regardless of the static (sub)type.
	private CCodeExpression supra_signal_instance (Class cl, Expression? inner) {
		CCodeExpression cinst;
		if (inner != null) {
			cinst = get_ccodenode (inner);
		} else {
			cinst = new CCodeIdentifier ("self");
		}
		return new CCodeCastExpression (cinst, "%s*".printf (get_ccode_name (cl)));
	}
}
