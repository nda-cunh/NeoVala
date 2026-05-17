/* valaccodesupramodule.vala
 * 
 */

using GLib;

public class Vala.CCodeSupraModule : CCodeDelegateModule {

	public override void visit_cast_expression (CastExpression expr) {
		var sym = expr.target_type.type_symbol;
		var to_type = get_ccode_upper_case_name (sym);
		var name = get_ccode_name (sym);
		expr.inner.accept(this);
		var is_macro = new CCodeIdentifier("IS_%s".printf(to_type));
		var condition = new CCodeFunctionCall(is_macro);
		condition.add_argument(get_cvalue(expr.inner));
		var cast_expr = new CCodeCastExpression(get_cvalue(expr.inner), "%s*".printf(name));
		var ternary = new CCodeConditionalExpression(condition, cast_expr, new CCodeConstant("NULL"));
		set_cvalue(expr, ternary);
	}

	public override void visit_class (Class cl) {
		if (!cl.is_supraklass) {
			base.visit_class (cl);
			return;
		}
		cfile.add_include ("stdlib.h");
		cfile.add_include ("stdbool.h");

		push_context (new EmitContext (cl));
		push_line (cl.source_reference);

		generate_supra_struct_declaration (cl, cfile);
		if (!cl.is_internal_symbol ()) {
			generate_supra_struct_declaration (cl, header_file);
		}

		cl.accept_children (this);


		if (cl.base_class == null) {
			generate_is_method_base (cl);
			generate_is_method (cl);
		}
		else {
			generate_is_method (cl);
		}

		generate_supra_vtable_and_init (cl);

		pop_line ();
		pop_context ();
	}

	private void generate_is_method (Class cl) {
		var root_cl = get_root_class (cl);
		string macro = "#define IS_%s(obj) (%s_is_a((void*) (obj), (const void*) &%s_VTABLE))\n".printf (
				get_ccode_upper_case_name (cl),
				get_ccode_name (root_cl),
				get_ccode_upper_case_name (cl)
				);
		cfile.add_type_member_declaration (new CCodeIdentifier (macro));
		header_file.add_type_member_declaration (new CCodeIdentifier (macro));
	}

	private void generate_is_method_base (Class cl) {
		var cname = get_ccode_name (cl);
		var vtable_type = "t_%sVtable".printf (cname);

		var vfunc = new CCodeFunction ("%s_is_a".printf(cname), "bool");
		vfunc.add_parameter (new CCodeParameter ("obj", "void*"));
		vfunc.add_parameter (new CCodeParameter ("target", "const void*"));

		cfile.add_function_declaration (vfunc);
		push_function (vfunc);

		var cond_null = new CCodeBinaryExpression(
				CCodeBinaryOperator.EQUALITY,
				new CCodeIdentifier("obj"),
				new CCodeConstant("NULL")
				);
		var if_null = new CCodeIfStatement(cond_null, new CCodeReturnStatement(new CCodeConstant("false")));
		ccode.add_statement(if_null);

		var cast_to_class = new CCodeCastExpression(new CCodeIdentifier("obj"), "%s*".printf(cname));
		var vptr_access = new CCodeMemberAccess.pointer(cast_to_class, "vptr");
		ccode.add_declaration(
				"const %s*".printf(vtable_type),
				new CCodeVariableDeclarator("current", vptr_access)
				);

		var while_cond = new CCodeBinaryExpression(
				CCodeBinaryOperator.INEQUALITY,
				new CCodeIdentifier("current"),
				new CCodeConstant("NULL")
				);
		ccode.open_while(while_cond);

		var cond_found = new CCodeBinaryExpression(
				CCodeBinaryOperator.EQUALITY,
				new CCodeIdentifier("current"),
				new CCodeIdentifier("target")
				);
		var if_found = new CCodeIfStatement(cond_found, new CCodeReturnStatement(new CCodeConstant("true")));
		ccode.add_statement(if_found);

		var next_parent = new CCodeMemberAccess.pointer(new CCodeIdentifier("current"), "_vala_parent");
		ccode.add_assignment(new CCodeIdentifier("current"), next_parent);

		ccode.close();

		ccode.add_return(new CCodeConstant("false"));

		pop_function();
		cfile.add_function(vfunc);
	}

	public override void visit_typeof_expression (TypeofExpression expr) {
	}

	public override void visit_method (Method m) {
		unowned Class? cl = m.parent_symbol as Class;
		if (cl == null || !cl.is_supraklass) {
			base.visit_method (m);
			return;
		}

		if ((m.is_virtual || m.is_abstract) && !m.overrides) {
			generate_supra_virtual_wrapper(m);
		}

		if (m.body != null) {
			generate_supra_real_method(m);
			return;
		}
	}

	public override bool generate_method_declaration (Method m, CCodeFile decl_space) {
		var cl = m.parent_symbol as Class;
		if (cl != null && cl.is_supraklass) {
			if (m is CreationMethod) {
				var func = new CCodeFunction(get_ccode_name(m), get_ccode_name(cl) + "*");
				func.add_parameter(new CCodeParameter("void", ""));
				decl_space.add_function_declaration(func);
				return true;
			}
			if (m.binding == MemberBinding.INSTANCE) {
				var func = new CCodeFunction(get_ccode_name(m), "void");
				func.add_parameter(new CCodeParameter("self", get_ccode_name(cl) + "*"));
				decl_space.add_function_declaration(func);
				return true;
			}
			return true;
		}
		return base.generate_method_declaration(m, decl_space);
	}

	private void generate_supra_real_method (Method m) {
		unowned Class cl = (Class) m.parent_symbol;
		string real_name = get_ccode_real_name(m);

		var func_wrapper = new CCodeFunction (real_name, get_ccode_name (m.return_type));
		func_wrapper.add_parameter (new CCodeParameter ("self", "%s*".printf (get_ccode_name (cl))));
		cfile.add_function_declaration (func_wrapper);

		push_function (func_wrapper);

		if (m.body != null) {
			m.body.accept (this);
		}

		pop_function ();
		cfile.add_function (func_wrapper);
	}

	private void generate_supra_virtual_wrapper (Method m) {
		unowned Class cl = (Class) m.parent_symbol;
		string real_name = get_ccode_real_name(m);
		string cname = get_ccode_name (m);

		var wrapper_func = new CCodeFunction (cname, get_ccode_name (m.return_type));
		wrapper_func.add_parameter (new CCodeParameter ("base", "%s*".printf (get_ccode_name (cl))));
		foreach (Parameter param in m.get_parameters ()) {
			wrapper_func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}
		cfile.add_function_declaration (wrapper_func);

		push_function (wrapper_func);

		var vtable_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("base"), "vptr");
		var method_ptr = new CCodeMemberAccess.pointer (vtable_access, get_ccode_vfunc_name (m));

		var vcall = new CCodeFunctionCall (method_ptr);
		vcall.add_argument (new CCodeIdentifier ("base"));

		if (m.return_type is VoidType) {
			ccode.add_expression (vcall);
		} else {
			ccode.add_return (vcall);
		}
		pop_function ();
		cfile.add_function (wrapper_func);



	}

	public override void visit_property (Property prop) {

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
			instance_struct.add_field ("size_t", "ref_count");
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
		else
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

		if (d.body != null) {
			d.body.accept (this);
		}

		if (cl.base_class != null) {
			var parent_cname_lower = get_ccode_lower_case_name (cl.base_class);
			var parent_finalize = new CCodeFunctionCall (new CCodeIdentifier ("%s_finalize".printf (parent_cname_lower)));
			parent_finalize.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "%s*".printf (get_ccode_name (cl.base_class))));
			ccode.add_expression (parent_finalize);
		}

		pop_function ();
		cfile.add_function (finalize_func);
		pop_line ();
	}


	public override void visit_creation_method (CreationMethod m) {
		unowned Class? cl = m.parent_symbol as Class;

		if (cl != null && cl.is_supraklass) {

			push_line(m.source_reference);

			string cname = get_ccode_name(cl);
			string real_cname = get_ccode_name(m);

			var vfunc = new CCodeFunction(real_cname, "%s*".printf(cname));

			foreach (var param in m.get_parameters()) {
				vfunc.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
			}

			push_function(vfunc);

			var alloc_call = new CCodeFunctionCall(new CCodeIdentifier("malloc"));
			alloc_call.add_argument(new CCodeIdentifier("sizeof (%s)".printf(cname)));
			ccode.add_declaration("%s*".printf(cname), new CCodeVariableDeclarator("self"));
			ccode.add_assignment(new CCodeIdentifier("self"), new CCodeCastExpression(alloc_call, "%s*".printf(cname)));

			var init_call = new CCodeFunctionCall(new CCodeIdentifier("init_%s".printf(cname)));
			init_call.add_argument(new CCodeIdentifier("self"));
			foreach (var param in m.get_parameters()) {
				init_call.add_argument (new CCodeIdentifier (param.name));
			}
			ccode.add_expression(init_call);

			ccode.add_return(new CCodeIdentifier("self"));

			pop_function();
			cfile.add_function(vfunc);
			cfile.add_function_declaration(vfunc);

			generate_supra_init_func (cl, m);

			pop_line();
			return; 
		}

		base.visit_creation_method(m);
	}


	private void generate_supra_vtable_and_init (Class cl) {
		generate_supra_vtable_struct (cl);
		generate_supra_vtable_var (cl);
		generate_supra_unref_func (cl); 
	}

	private void generate_supra_vtable_struct (Class cl) {
		string cname = get_ccode_name (cl);
		var vtable_struct = new CCodeStruct ("s_%sVtable".printf (cname));

		vtable_struct.add_field ("void", "(*finalize)(void*)");
		vtable_struct.add_field ("const void*", "_vala_parent");

		unowned Class root_cl = cl;
		while (root_cl.base_class != null) {
			root_cl = root_cl.base_class;
		}

		foreach (Method m in root_cl.get_methods ()) {
			if (m.is_virtual || m.is_abstract) {
				string field_name = get_ccode_vfunc_name (m);
				vtable_struct.add_field ("void", "(*%s)(void*)".printf (field_name));
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

		membres.append (".finalize = ");
		if (cl.destructor != null) {
			membres.append ("(void (*)(void*)) %s_finalize".printf (cname_lower));
		} else if (cl.base_class != null) {
			membres.append ("(void (*)(void*)) %s_finalize".printf (get_ccode_lower_case_name (cl.base_class)));
		} else {
			membres.append ("NULL");
		}
		membres.append (",\n\t\t");

		// Dans ta boucle de génération de la variable static const
		if (cl.base_class != null) {
			membres.append ("._vala_parent = (const t_PersoVtable*) &%s_VTABLE".printf (
						get_ccode_upper_case_name (cl.base_class)
						));
		} else {
			membres.append ("._vala_parent = NULL");
		}




		unowned Class root_cl = cl;
		while (root_cl.base_class != null) {
			root_cl = root_cl.base_class;
		}

		foreach (Method m_base in root_cl.get_methods ()) {
			if (m_base.is_virtual || m_base.is_abstract) {
				membres.append (",\n\t\t");

				string field_name = get_ccode_vfunc_name (m_base);
				membres.append (".%s = ".printf (field_name));

				Method? implementation = null;
				foreach (Method m_target in cl.get_methods()) {
					if (m_target.overrides && m_target.base_method == m_base) {
						implementation = m_target;
						break;
					}
				}

				if (implementation != null) {
					membres.append ("(void (*)(void*)) %s".printf(get_ccode_real_name(implementation)));
				} else if (m_base.is_abstract) {
					membres.append ("NULL");
				} else {
					membres.append ("(void (*)(void*)) %s".printf(get_ccode_real_name(m_base)));
				}
			}
		}

		string ligne_vtable = "static const t_%sVtable %s = {\n\t\t%s\n};".printf (
				cname,
				vtable_var_name,
				membres.str
				);

		cfile.add_type_member_declaration (new CCodeIdentifier (ligne_vtable));
	}

	private void generate_supra_init_func (Class cl, CreationMethod m) {
		string cname = get_ccode_name (cl);
		string vtable_var_name = "%s_VTABLE".printf (get_ccode_upper_case_name (cl));

		var init_context = new EmitContext (m);
		push_context (init_context);

		var init_func = new CCodeFunction ("init_%s".printf (cname), "void");
		init_func.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));

		foreach (Parameter param in m.get_parameters ()) {
			init_func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}

		cfile.add_function_declaration (init_func);
		push_function (init_func);

		if (cl.base_class != null) {
			var base_init_call = new CCodeFunctionCall (new CCodeIdentifier ("init_%s".printf (get_ccode_name (cl.base_class))));
			base_init_call.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "%s*".printf (get_ccode_name (cl.base_class))));

			ccode.add_expression (base_init_call);
		}

		string base_class_name = cl.base_class != null ? get_ccode_name (cl.base_class) : "Perso";
		var vptr_access = new CCodeMemberAccess.pointer (new CCodeCastExpression (new CCodeIdentifier ("self"), "Perso*"), "vptr");

		ccode.add_assignment (
				vptr_access,
				new CCodeCastExpression (
					new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (vtable_var_name)),
					"const t_PersoVtable*"
					)
				);


		foreach (Field f in cl.get_fields ()) {
			if (f.binding == MemberBinding.INSTANCE) {
				var field_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), get_ccode_name (f));
				ccode.add_assignment (field_access, new CCodeConstant ("0"));
			}
		}

		if (m.body != null) {

			foreach (var stmt in m.body.get_statements ()) {
				if (stmt is ExpressionStatement) {
					var expr = ((ExpressionStatement) stmt).expression;
					if (expr is MethodCall && ((MethodCall) expr).call is BaseAccess) {
						continue; 
					}
				}

				stmt.emit (this);
			}
		}

		pop_function ();

		cfile.add_function (init_func);

		pop_context ();
	}

	public override void generate_class_struct_declaration (Class cl, CCodeFile decl_space) {
		if (cl.get_attribute ("SupraKlass") == null) {
			base.generate_class_struct_declaration (cl, decl_space);
			return;
		}

		if (add_symbol_declaration (decl_space, cl, get_ccode_name (cl))) {
			return;
		}
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
			unowned Vala.Class root_cl = get_root_class (cl);
			string base_class_name = get_ccode_name (root_cl);

			var finalize_call = new CCodeFunctionCall (new CCodeMemberAccess.pointer (new CCodeIdentifier ("((%s*)self)".printf (base_class_name)), "vptr->finalize"));
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


private unowned Vala.Class get_root_class (Vala.Class cl) {
	unowned Vala.Class root = cl;
	while (root.base_class != null) {
		root = root.base_class;
	}
	return root;
}
