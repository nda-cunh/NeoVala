/* valaccodesupramodule.vala
 * 
 */

using GLib;

public class Vala.CCodeSupraModule : CCodeDelegateModule {


	public override void visit_class (Class cl) {
		if (!cl.is_supraklass) {
			base.visit_class (cl);
			return;
		}
		cfile.add_include ("stdlib.h");

		push_context (new EmitContext (cl));
		push_line (cl.source_reference);

		generate_supra_struct_declaration (cl, cfile);
		if (!cl.is_internal_symbol ()) {
			generate_supra_struct_declaration (cl, header_file);
		}

		cl.accept_children (this);

		generate_supra_vtable_and_init (cl);

		pop_line ();
		pop_context ();
	}

	public override void visit_method (Method m) {
		unowned Class? cl = m.parent_symbol as Class;
		if (cl == null || !cl.is_supraklass) {
			base.visit_method (m);
			return;
		}

		// Todo pour les class virtual  ( le fat pointef)
		base.visit_method (m);
	}

	private void generate_supra_struct_declaration (Class cl, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, cl, "struct _%s".printf (get_ccode_name (cl)))) {
			return;
		}

		string cname = get_ccode_name (cl);

		decl_space.add_type_declaration (new CCodeTypeDefinition ("struct _%s".printf (cname), new CCodeVariableDeclarator (cname)));

		var instance_struct = new CCodeStruct ("_%s".printf (cname));

		if (cl.base_class == null) {
			instance_struct.add_field ("const t_%sVtable*".printf (cname), "vptr");
		} else {
			instance_struct.add_field (get_ccode_name (cl.base_class), "parent");
		}

		foreach (Field f in cl.get_fields ()) {
			if (f.binding == MemberBinding.INSTANCE) {
				instance_struct.add_field (get_ccode_name (f.variable_type), get_ccode_name (f));
			}
		}

		decl_space.add_type_definition (instance_struct);
	}


	public override void visit_local_variable (LocalVariable local) {
		unowned Class? cl = local.variable_type.type_symbol as Class;

		if (cl != null && cl.is_supraklass) {
			bool old_owned = local.variable_type.value_owned;
			local.variable_type.value_owned = false;

			base.visit_local_variable (local);

			local.variable_type.value_owned = old_owned;
			return;
		}

		base.visit_local_variable (local);
	}

	public override void visit_object_creation_expression (ObjectCreationExpression expr) {
		unowned Class? cl = expr.type_reference.type_symbol as Class;
		if (cl != null && cl.is_supraklass) {
			string cname = get_ccode_name (cl);
			string cname_lower = get_ccode_lower_case_name (cl);

			var new_proto = new CCodeFunction ("%s_new".printf (cname_lower), "%s*".printf (cname));
			cfile.add_function_declaration (new_proto);

			var new_call = new CCodeFunctionCall (new CCodeIdentifier ("%s_new".printf (cname_lower)));

			foreach (Expression arg in expr.get_argument_list ()) {
				arg.accept (this);
				new_call.add_argument (get_cvalue (arg));
			}

			if (expr.value_type != null) {
				expr.value_type.value_owned = true;
			}
			if (expr.target_type != null) {
				expr.target_type.value_owned = true;
			}

			set_cvalue (expr, new_call);

			return;
		}
		base.visit_object_creation_expression (expr);
	}

	public override void visit_destructor (Destructor d) {
		unowned Class? cl = d.parent_symbol as Class;
		if (cl == null || !cl.is_supraklass) {
			base.visit_destructor (d);
			return;
		}

		push_line (d.source_reference);
		string cname = get_ccode_name (cl);
		string cname_lower = get_ccode_lower_case_name (cl);

		var finalize_func = new CCodeFunction ("%s_finalize".printf (cname_lower), "void");
		finalize_func.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));
		finalize_func.modifiers = CCodeModifiers.STATIC;
		cfile.add_function_declaration (finalize_func);
		push_function (finalize_func);


		if (cl.base_class != null) {
			var parent_cname_lower = get_ccode_lower_case_name (cl.base_class);
			var parent_finalize = new CCodeFunctionCall (new CCodeIdentifier ("%s_finalize".printf (parent_cname_lower)));
			parent_finalize.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "%s*".printf (get_ccode_name (cl.base_class))));
			ccode.add_expression (parent_finalize);
		}

		if (d.body != null) {
			d.body.accept (this);
		}

		pop_function ();
		cfile.add_function (finalize_func);
		pop_line ();
	}

	public override void visit_creation_method (CreationMethod m) {
		unowned Class? cl = m.parent_symbol as Class;

		push_line (m.source_reference);
		string cname = get_ccode_name (cl);
		string real_cname = get_ccode_name (m);

		var vfunc = new CCodeFunction (real_cname);
		vfunc.return_type = "%s*".printf (cname);
		push_function (vfunc);

		var alloc_call = new CCodeFunctionCall (new CCodeIdentifier ("malloc"));
		alloc_call.add_argument (new CCodeIdentifier ("sizeof (%s)".printf (cname)));

		ccode.add_declaration ("%s*".printf (cname), new CCodeVariableDeclarator ("self"));
		ccode.add_assignment (new CCodeIdentifier ("self"), new CCodeCastExpression (alloc_call, "%s*".printf (cname)));

		var init_call = new CCodeFunctionCall (new CCodeIdentifier ("init_%s".printf (cname)));
		init_call.add_argument (new CCodeIdentifier ("self"));
		ccode.add_expression (init_call);
		if (m.body != null) {
			m.body.accept (this);
		}
		ccode.add_return (new CCodeIdentifier ("self"));

		pop_function ();
		cfile.add_function (vfunc);
		pop_line ();
	}

	private void generate_supra_vtable_and_init (Class cl) {
		generate_supra_vtable_struct (cl);
		generate_supra_vtable_var (cl);
		generate_supra_init_func (cl);         // génère void init_MaClasse (MaClasse* self) { ... }
		generate_supra_unref_func (cl);        // génère void ma_classe_unref (MaClasse* self) { ... }
	}

	private void generate_supra_vtable_struct (Class cl) {
		string cname = get_ccode_name (cl);
		var vtable_struct = new CCodeStruct ("s_%sVtable".printf (cname));
		vtable_struct.add_field ("void", "(*finalize)(void*)");

		foreach (Method m in cl.get_methods ()) {
			if (m.is_virtual || m.is_abstract || m.overrides) {
				vtable_struct.add_field ("void", "(*%s)(void*)".printf (get_ccode_name (m)));
			}
		}
		cfile.add_type_declaration (new CCodeTypeDefinition (
					"struct s_%sVtable".printf (cname),
					new CCodeVariableDeclarator ("t_%sVtable".printf (cname))));
		cfile.add_type_definition (vtable_struct);
	}


private void generate_supra_vtable_var (Class cl) {
    string cname = get_ccode_name (cl);
    string cname_lower = get_ccode_lower_case_name (cl);
    string vtable_var_name = "%s_VTABLE".printf (get_ccode_upper_case_name (cl));

    var membres = new StringBuilder ();

    if (cl.destructor != null) {
        membres.append ("(void (*)(void*)) %s_finalize".printf (cname_lower));
    } else {
        membres.append ("NULL");
    }

    foreach (Method m in cl.get_methods ()) {
        if (m.is_virtual || m.is_abstract || m.overrides) {
            membres.append (", "); // séparateur C
            membres.append ("(void (*)(void*)) %s".printf (get_ccode_name (m)));
        }
    }

    string ligne_vtable = "static const t_%sVtable %s = { %s };".printf (
        cname,
        vtable_var_name,
        membres.str
    );

    cfile.add_type_member_declaration (new CCodeIdentifier (ligne_vtable));
}


	private void generate_supra_init_func (Class cl) {
		string cname = get_ccode_name (cl);
		string vtable_var_name = "%s_VTABLE".printf (get_ccode_upper_case_name (cl));

		var init_func = new CCodeFunction ("init_%s".printf (cname), "void");
		init_func.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));
		cfile.add_function_declaration (init_func);
		push_function (init_func);

		var vptr_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "vptr");
		ccode.add_assignment (
				vptr_access,
				new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (vtable_var_name))
				);

		foreach (Field f in cl.get_fields ()) {
			if (f.binding == MemberBinding.INSTANCE) {
				var field_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), get_ccode_name (f));
				ccode.add_assignment (field_access, new CCodeConstant ("0"));
			}
		}

		pop_function ();
		cfile.add_function (init_func);
	}

	private void generate_supra_unref_func (Class cl) {
		string cname = get_ccode_name (cl);
		string cname_lower = get_ccode_lower_case_name (cl);

		var unref_func = new CCodeFunction ("%s_unref".printf (cname_lower), "void");
		unref_func.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));
		push_function (unref_func);
		var self_null = new CCodeBinaryExpression (
				CCodeBinaryOperator.EQUALITY,
				new CCodeIdentifier ("self"),
				new CCodeConstant ("NULL")
				);
		ccode.open_if (self_null);
		ccode.add_return ();
		ccode.close ();

		if (cl.destructor != null) {
			var finalize_call = new CCodeFunctionCall (new CCodeIdentifier ("%s_finalize".printf (cname_lower)));
			finalize_call.add_argument (new CCodeIdentifier ("self"));
			ccode.add_expression (finalize_call);
		}
		var free_call = new CCodeFunctionCall (new CCodeIdentifier ("free"));
		free_call.add_argument (new CCodeIdentifier ("self"));
		ccode.add_expression (free_call);

		pop_function ();
		cfile.add_function (unref_func);
	}
}
