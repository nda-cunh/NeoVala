/* valaccodesupraerrormodule.vala
 *
 * GLib-free error handling for the POSIX (supra) backend: a flat heap
 * t_vala_Error struct, address-based errordomain identity, and throw /
 * try / catch reimplemented independently of GErrorModule. Split out of
 * CCodeSupraModule; sits low in the supra chain.
 */

using Vala;

public class Vala.CCodeSupraErrorModule : CCodeDelegateModule {

	private bool is_in_supra_catch = false;

	protected void emit_supra_error_runtime () {
		if (!add_wrapper ("t_vala_Error")) {
			return;
		}
		cfile.add_include ("stdlib.h");
		cfile.add_include ("string.h");
		cfile.add_include ("stdio.h");
		cfile.add_include ("stdarg.h");
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"""typedef struct { const void* domain; int code; char* message; } t_vala_Error;

static t_vala_Error* _vala_error_new_literal (const void* domain, int code, const char* message) {
	t_vala_Error* e = (t_vala_Error*) malloc (sizeof (t_vala_Error));
	e->domain = domain;
	e->code = code;
	e->message = (message != NULL) ? strdup (message) : NULL;
	return e;
}

static t_vala_Error* _vala_error_new (const void* domain, int code, const char* format, ...) {
	char buf[1024];
	va_list ap;
	va_start (ap, format);
	vsnprintf (buf, sizeof (buf), format, ap);
	va_end (ap);
	return _vala_error_new_literal (domain, code, buf);
}

static t_vala_Error* _vala_error_copy (t_vala_Error* e) {
	if (e == NULL) {
		return NULL;
	}
	return _vala_error_new_literal (e->domain, e->code, e->message);
}

static void _vala_error_free (t_vala_Error* e) {
	if (e != NULL) {
		free (e->message);
		free (e);
	}
}"""));
	}

	public override void generate_error_domain_declaration (ErrorDomain edomain, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, edomain, get_ccode_name (edomain))) {
			return;
		}

		string upper = get_ccode_upper_case_name (edomain);

		var cenum = new CCodeEnum (get_ccode_name (edomain));
		foreach (ErrorCode ecode in edomain.get_codes ()) {
			if (ecode.value == null) {
				cenum.add_value (new CCodeEnumValue (get_ccode_name (ecode)));
			} else {
				ecode.value.emit (this);
				cenum.add_value (new CCodeEnumValue (get_ccode_name (ecode), get_cvalue (ecode.value)));
			}
		}
		decl_space.add_type_definition (cenum);

		// Domain identity is the ADDRESS of a single shared marker symbol. It must
		// be ONE extern object across all TUs (not `static`, which gives each TU a
		// distinct address and breaks domain comparison in another file); the
		// definition is emitted once by visit_error_domain.
		decl_space.add_type_definition (new CCodeIdentifier (
			"extern const char %s_DOMAIN_ID;".printf (upper)));
		decl_space.add_type_definition (new CCodeMacroReplacement (upper, "(&%s_DOMAIN_ID)".printf (upper)));
		decl_space.add_type_definition (new CCodeNewline ());
	}

	public override void visit_error_domain (ErrorDomain edomain) {
		emit_supra_error_runtime ();
		generate_error_domain_declaration (edomain, cfile);
		// single definition of the identity marker (the domain's home TU)
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"\nconst char %s_DOMAIN_ID = 0;\n".printf (get_ccode_upper_case_name (edomain))));
		if (!edomain.is_internal_symbol ()) {
			generate_error_domain_declaration (edomain, header_file);
		}
		if (!edomain.is_private_symbol ()) {
			generate_error_domain_declaration (edomain, internal_header_file);
		}
		edomain.accept_children (this);
	}

	public override void visit_throw_statement (ThrowStatement stmt) {
		emit_supra_error_runtime ();
		current_method_inner_error = true;
		ccode.add_assignment (get_inner_error_cexpression (), get_cvalue (stmt.error_expression));
		add_simple_check (stmt, true);
	}

	private void supra_return_with_exception (CCodeExpression error_expr) {
		ccode.open_if (new CCodeIdentifier ("error"));
		ccode.add_expression (new CCodeAssignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("error")), error_expr));
		ccode.add_else ();
		var free_call = new CCodeFunctionCall (new CCodeIdentifier ("_vala_error_free"));
		free_call.add_argument (error_expr);
		ccode.add_expression (free_call);
		ccode.close ();

		append_local_free (current_symbol);
		append_out_param_free (current_method);

		if (current_method is CreationMethod && current_method.parent_symbol is Class) {
			// The supra `_init` is a void function; it signals failure through
			// *error and its `_new` wrapper drops the half-built object.
			ccode.add_return ();
		} else {
			return_default_value (current_return_type, true);
		}
	}

	private void supra_uncaught_error_statement (CCodeExpression inner_error) {
		append_local_free (current_symbol);
		append_out_param_free (current_method);

		var free_call = new CCodeFunctionCall (new CCodeIdentifier ("_vala_error_free"));
		free_call.add_argument (inner_error);
		ccode.add_expression (free_call);
		ccode.add_assignment (inner_error, new CCodeConstant ("NULL"));

		if (current_method is CreationMethod && current_method.parent_symbol is Class) {
			ccode.add_return ();
		} else if (current_return_type != null && !(current_return_type is VoidType)) {
			return_default_value (current_return_type, true);
		} else if (current_method != null) {
			ccode.add_return ();
		}
	}

	private CCodeExpression supra_domain_check (DataType error_type) {
		return new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY,
			new CCodeMemberAccess.pointer (get_inner_error_cexpression (), "domain"),
			new CCodeIdentifier (get_ccode_upper_case_name (((ErrorType) error_type).error_domain)));
	}

	public override void add_simple_check (CodeNode node, bool always_fails = false) {
		emit_supra_error_runtime ();
		current_method_inner_error = true;

		if (!always_fails) {
			var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, get_inner_error_cexpression (), new CCodeConstant ("NULL"));
			ccode.open_if (ccond);
		}

		if (current_try != null) {
			if (is_in_supra_catch) {
				append_local_free (current_symbol, null, current_catch);
			} else {
				append_local_free (current_symbol, null, current_try);
			}

			var error_types = new ArrayList<DataType> ();
			node.get_error_types (error_types);
			bool has_general_catch_clause = false;

			if (!is_in_supra_catch) {
				foreach (CatchClause clause in current_try.get_catch_clauses ()) {
					unowned ErrorType catch_type = (ErrorType) clause.error_type;
					if (catch_type.error_domain == null) {
						has_general_catch_clause = true;
						ccode.add_goto (clause.get_attribute_string ("CCode", "cname"));
						break;
					}

					CCodeExpression ccond = supra_domain_check (catch_type);
					if (catch_type.error_code != null) {
						ccond = new CCodeBinaryExpression (CCodeBinaryOperator.AND, ccond,
							new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY,
								new CCodeMemberAccess.pointer (get_inner_error_cexpression (), "code"),
								new CCodeIdentifier (get_ccode_name (catch_type.error_code))));
					}
					ccode.open_if (ccond);
					ccode.add_goto (clause.get_attribute_string ("CCode", "cname"));
					ccode.close ();
				}
			}

			if (has_general_catch_clause) {
				// fully handled
			} else {
				ccode.add_goto ("__finally%d".printf (current_try_id));
			}
		} else if (current_method != null && current_method.tree_can_fail) {
			CCodeExpression ccond = null;
			var error_types = new ArrayList<DataType> ();
			current_method.get_error_types (error_types);
			foreach (DataType error_type in error_types) {
				if (((ErrorType) error_type).error_domain == null) {
					ccond = null;
					break;
				}
				var domain_check = supra_domain_check (error_type);
				ccond = (ccond == null) ? domain_check : new CCodeBinaryExpression (CCodeBinaryOperator.OR, ccond, domain_check);
			}

			if (ccond != null) {
				ccode.open_if (ccond);
				supra_return_with_exception (get_inner_error_cexpression ());
				ccode.add_else ();
				supra_uncaught_error_statement (get_inner_error_cexpression ());
				ccode.close ();
			} else {
				supra_return_with_exception (get_inner_error_cexpression ());
			}
		} else {
			supra_uncaught_error_statement (get_inner_error_cexpression ());
		}

		if (!always_fails) {
			ccode.close ();
		}
	}

	public override void visit_try_statement (TryStatement stmt) {
		emit_supra_error_runtime ();
		int this_try_id = next_try_id++;

		var old_try = current_try;
		var old_try_id = current_try_id;
		var old_is_in_catch = is_in_supra_catch;
		var old_catch = current_catch;
		current_try = stmt;
		current_try_id = this_try_id;
		is_in_supra_catch = true;

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			clause.set_attribute_string ("CCode", "cname", "__catch%d_%s".printf (this_try_id, get_ccode_lower_case_name (clause.error_type)));
		}

		is_in_supra_catch = false;
		stmt.body.emit (this);
		is_in_supra_catch = true;

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			current_catch = clause;
			ccode.add_goto ("__finally%d".printf (this_try_id));
			clause.emit (this);
		}

		current_try = old_try;
		current_try_id = old_try_id;
		is_in_supra_catch = old_is_in_catch;
		current_catch = old_catch;

		ccode.add_label ("__finally%d".printf (this_try_id));
		if (stmt.finally_body != null) {
			stmt.finally_body.emit (this);
		}

		add_simple_check (stmt, !stmt.after_try_block_reachable);
	}

	public override void visit_catch_clause (CatchClause clause) {
		current_method_inner_error = true;

		var error_type = (ErrorType) clause.error_type;
		if (error_type.error_domain != null) {
			generate_error_domain_declaration (error_type.error_domain, cfile);
		}

		ccode.add_label (clause.get_attribute_string ("CCode", "cname"));
		ccode.open_block ();

		if (clause.error_variable != null && clause.error_variable.used) {
			visit_local_variable (clause.error_variable);
			ccode.add_assignment (get_variable_cexpression (get_local_cname (clause.error_variable)), get_inner_error_cexpression ());
			ccode.add_assignment (get_inner_error_cexpression (), new CCodeConstant ("NULL"));
		} else {
			if (clause.error_variable != null) {
				clause.error_variable.unreachable = true;
			}
			var free_call = new CCodeFunctionCall (new CCodeIdentifier ("_vala_error_free"));
			free_call.add_argument (get_inner_error_cexpression ());
			ccode.add_expression (free_call);
			ccode.add_assignment (get_inner_error_cexpression (), new CCodeConstant ("NULL"));
		}

		clause.body.emit (this);
		ccode.close ();
	}

}
