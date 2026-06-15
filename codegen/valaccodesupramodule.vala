/* valaccodesupramodule.vala
 * 
 */

using Vala;

public class Vala.CCodeSupraModule : CCodeDelegateModule {

	public override void generate_class_declaration (Class cl, CCodeFile decl_space)
	{
		if (cl.base_class != null) {
			generate_class_declaration (cl.base_class, decl_space);
		}

		foreach (Field f in cl.get_fields ()) {
			var field_type = f.variable_type.type_symbol;
			if (field_type is Class) {
				generate_class_declaration ((Class)field_type, decl_space);
			}
		}

		decl_space.add_include ("stdlib.h");
		decl_space.add_include ("stddef.h");
		decl_space.add_include ("stdbool.h");

		if (add_symbol_declaration (decl_space, cl, get_ccode_name (cl))) {
			return;
		}

		generate_vtable_declaration (cl, decl_space);
		generate_instance_struct_declaration (cl, decl_space);

		if (cl.base_class == null) {
			generate_ref_function_declaration (cl, decl_space);
		}

		generate_is_object_macro (cl, decl_space);

		generate_supra_class_externs (cl, decl_space);
	}

	private void generate_supra_class_externs (Class cl, CCodeFile decl_space) {
		string cname = get_ccode_name (cl);
		string cname_lower = get_ccode_lower_case_name (cl);

		// extern declaration of the vtable instance (defined in the class' own
		// compilation unit) so subclasses can reference it via _vala_parent.
		decl_space.add_type_member_declaration (new CCodeIdentifier (
			"extern const t_%sVtable %s_VTABLE;\n".printf (cname, get_ccode_upper_case_name (cl))));

		// finalize, called directly by a subclass' finalize.
		var fin = new CCodeFunction ("%s_finalize".printf (cname_lower), "void");
		fin.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));
		decl_space.add_function_declaration (fin);

		// is_a, referenced by the IS_* macros.
		var root_cl = get_root_class (cl);
		var is_a = new CCodeFunction ("%s_is_a".printf (get_ccode_name (root_cl)), "bool");
		is_a.add_parameter (new CCodeParameter ("obj", "void*"));
		is_a.add_parameter (new CCodeParameter ("target", "const void*"));
		decl_space.add_function_declaration (is_a);

		// constructors (_new and _init), called by subclass chain-up and by users.
		foreach (Method m in cl.get_methods ()) {
			if (!(m is CreationMethod)) {
				continue;
			}
			string method_suffix = (m.name == ".new") ? "" : "_" + m.name;

			var new_func = new CCodeFunction (get_ccode_name (m), "%s*".printf (cname));
			var init_func = new CCodeFunction ("%s_init%s".printf (cname_lower, method_suffix), "void");
			init_func.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));
			foreach (Parameter param in m.get_parameters ()) {
				new_func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
				init_func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
			}
			decl_space.add_function_declaration (new_func);
			decl_space.add_function_declaration (init_func);
		}
	}


	public override void visit_class (Class cl) {
		if (context.profile == Profile.POSIX) {
			cl.set_attribute ("SupraKlass", true);
			cl.is_supraklass = true;
		}
		if (!cl.is_supraklass) {
			base.visit_class (cl);
			return;
		}

		// With -H, the public declarations of a *public* class live in the
		// generated header (and every .c includes it). Internal classes and the
		// no-header case keep their declarations in cfile. Definitions are always
		// emitted to cfile.
		CCodeFile decl_space;
		if (context.header_filename != null && !cl.is_internal_symbol ()) {
			decl_space = header_file;
			cfile.add_include (Path.get_basename (context.header_filename), true);
		} else {
			decl_space = cfile;
		}
		decl_space.add_include ("stdlib.h");
		decl_space.add_include ("stddef.h");
		decl_space.add_include ("stdbool.h");

		// Make sure the base class (its struct and the symbols this class
		// inherits/references: vtable, _init, _finalize, ...) is fully declared
		// first. This is required when the parent lives in another compilation
		// unit, and guarantees the parent struct is complete before ours embeds
		// it by value.
		if (cl.base_class != null) {
			generate_class_declaration (cl.base_class, decl_space);
		}

		generate_private_struct_declaration (cl, decl_space);
		generate_instance_struct_declaration (cl, decl_space);

		cl.accept_children (this);

		if (cl.base_class == null) {
			generate_is_method_base (cl, decl_space);
			generate_unref_func (cl, decl_space); 
			generate_ref_function(cl, decl_space);
		}
		generate_is_object_macro (cl, decl_space);

		if (cl.destructor == null) {
			generate_destructor_function (cl, null);
		}

		generate_supra_vtable_and_init (cl, decl_space);
	}

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



	private void generate_is_object_macro (Class cl, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, cl, "IS_%s".printf(get_ccode_upper_case_name(cl)))) {
			return;
		} 
		var root_cl = get_root_class (cl);
		string macro = "#define IS_%s(obj) (%s_is_a((void*) (obj), (const void*) &%s_VTABLE))\n".printf (
			get_ccode_upper_case_name (cl),
			get_ccode_name (root_cl),
			get_ccode_upper_case_name (cl)
		);
		decl_space.add_type_member_declaration (new CCodeIdentifier (macro));
	}

	private void generate_is_method_base (Class cl, CCodeFile decl_space) {
		var cname = get_ccode_name (cl);
		var vtable_type = "t_%sVtable".printf (cname);

		var vfunc = new CCodeFunction ("%s_is_a".printf(cname), "bool");
		vfunc.add_parameter (new CCodeParameter ("obj", "void*"));
		vfunc.add_parameter (new CCodeParameter ("target", "const void*"));

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

		decl_space.add_function_declaration (vfunc);
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

		// emit the public/internal header declarations, like base.visit_method does
		// (creation methods declare their own _new/_init in visit_creation_method)
		if (!(m is CreationMethod)
		    && (m.is_abstract || m.is_virtual
		    || (m.base_method == null && m.base_interface_method == null))
		    && m.signal_reference == null) {
			if (!m.is_internal_symbol ()) {
				generate_method_declaration (m, header_file);
			}
			if (!m.is_private_symbol ()) {
				generate_method_declaration (m, internal_header_file);
			}
		}

		if ((m.is_virtual || m.is_abstract) && !m.overrides) {
			generate_supra_virtual_wrapper(m);
		}

		if (m.body != null) {
			generate_supra_real_method(m);
			return;
		}
		// abstract methods have no body: the virtual dispatch wrapper generated
		// above is all that is needed, so do not fall back to base.visit_method
		// (which would emit a second, conflicting definition).
		if (m.is_abstract) {
			return;
		}
		base.visit_method (m);
	}

	public override bool generate_method_declaration (Method m, CCodeFile decl_space) {
		var cl = m.parent_symbol as Class;
		if (cl != null && cl.is_supraklass) {
			if (add_symbol_declaration (decl_space, m, get_ccode_name (m))) {
				return true;
			}
			// make sure the owning class and any referenced types are
			// declared in the same decl_space (e.g. the public header)
			generate_class_declaration (cl, decl_space);

			if (m is CreationMethod) {
				var func = new CCodeFunction(get_ccode_name(m), get_ccode_name(cl) + "*");
				foreach (Parameter param in m.get_parameters()) {
					func.add_parameter(new CCodeParameter(param.name, get_ccode_name(param.variable_type)));
				}
				decl_space.add_function_declaration(func);
				return true;
			}
			if (m.binding == MemberBinding.INSTANCE) {
				var func = new CCodeFunction(get_ccode_name(m), get_ccode_name(m.return_type));
				func.add_parameter(new CCodeParameter("self", get_ccode_name(cl) + "*"));
				foreach (Parameter param in m.get_parameters()) {
					func.add_parameter(new CCodeParameter(param.name, get_ccode_name(param.variable_type)));
				}
				decl_space.add_function_declaration(func);
				return true;
			}
			return true;
		}
		return base.generate_method_declaration(m, decl_space);
	}

	// Declare (not define) the "real" implementation of a method, so a vtable
	// built in another compilation unit can reference an inherited implementation.
	private void declare_supra_real_method (Method m, CCodeFile decl_space) {
		unowned Class? owner = m.parent_symbol as Class;
		if (owner == null) {
			return;
		}
		var func = new CCodeFunction (get_ccode_real_name (m), get_ccode_name (m.return_type));
		func.add_parameter (new CCodeParameter ("self", "%s*".printf (get_ccode_name (owner))));
		foreach (Parameter param in m.get_parameters ()) {
			func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}
		decl_space.add_function_declaration (func);
	}

	private void generate_supra_real_method (Method m) {
		unowned Class cl = (Class) m.parent_symbol;
		string real_name = get_ccode_real_name(m);

		var func_wrapper = new CCodeFunction (real_name, get_ccode_name (m.return_type));
		func_wrapper.add_parameter (new CCodeParameter ("self", "%s*".printf (get_ccode_name (cl))));

		foreach (Parameter param in m.get_parameters ()) {
			func_wrapper.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}

		cfile.add_function_declaration (func_wrapper);

		push_function (func_wrapper);

		if (!(m.return_type is VoidType) && !m.return_type.is_real_non_null_struct_type ()) {
			ccode.add_declaration (get_ccode_name (m.return_type), new CCodeVariableDeclarator ("result"));
		}

		if (m.body != null) {
			m.body.accept (this);
		}

		pop_function ();
		cfile.add_function (func_wrapper);
	}

	private void generate_supra_virtual_wrapper (Method m) {
		unowned Class cl = (Class) m.parent_symbol;
		string cname = get_ccode_name (m);

		var wrapper_func = new CCodeFunction (cname, get_ccode_name (m.return_type));
		wrapper_func.add_parameter (new CCodeParameter ("base", "%s*".printf (get_ccode_name (cl))));
		foreach (Parameter param in m.get_parameters ()) {
			wrapper_func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}

		push_function (wrapper_func);

		var vtable_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("base"), "vptr");
		var method_ptr = new CCodeMemberAccess.pointer (vtable_access, get_ccode_vfunc_name (m));

		var vcall = new CCodeFunctionCall (method_ptr);
		vcall.add_argument (new CCodeIdentifier ("base"));

		foreach (Parameter param in m.get_parameters ()) {
			vcall.add_argument (new CCodeIdentifier (param.name));
		}

		if (m.return_type is VoidType) {
			ccode.add_expression (vcall);
		} else {
			ccode.add_return (vcall);
		}
		pop_function ();


		// TODO to decl_space
		cfile.add_function_declaration (wrapper_func);
		cfile.add_function (wrapper_func);

	}

	private void generate_private_struct_declaration (Class cl, CCodeFile decl_space) {
		if (!cl.has_private_fields) {
			return;
		}
		string cname = get_ccode_name (cl);

		// private struct
		var private_struct = new CCodeStruct ("s_%sPrivate".printf (cname));
		foreach (Field f in cl.get_fields ()) {
			if (f.is_private_symbol ()) {
				private_struct.add_field (get_ccode_name (f.variable_type), get_ccode_name (f));
			}
		}

		decl_space.add_type_declaration (new CCodeTypeDefinition ("struct s_%sPrivate".printf (cname), new CCodeVariableDeclarator ("t_%sPrivate".printf (cname))));
		cfile.add_type_definition (private_struct);
	}

	private void generate_instance_struct_declaration (Class cl, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, cl, "struct _%s".printf (get_ccode_name (cl)))) {
			return;
		}

		string cname = get_ccode_name (cl);

		// public struct
		{
			var struct_public = new CCodeStruct ("_%s".printf (cname));

			if (cl.base_class == null) {
				struct_public.add_field ("const t_%sVtable*".printf (cname), "vptr");
				struct_public.add_field ("size_t", "ref_count");
			} else {
				struct_public.add_field (get_ccode_name (cl.base_class), "parent");
			}

			foreach (Field f in cl.get_fields ()) {
				if (f.binding == MemberBinding.INSTANCE && !f.is_private_symbol ()) {
					struct_public.add_field (get_ccode_name (f.variable_type), get_ccode_name (f));
				}
			}
			if (cl.has_private_fields) {
				StringBuilder sb = new StringBuilder();
				sb.append("struct {");
				foreach (Field f in cl.get_fields ()) {
					if (f.is_private_symbol ()) {
						sb.append_printf("%s %s;", get_ccode_name (f.variable_type), get_ccode_name (f));
					}
				}
				sb.append("}");
				struct_public.add_field ("struct s_%sPrivate*".printf(cname), "priv");
				struct_public.add_field ("_Alignas(max_align_t) char", "_priv[sizeof(%s)]".printf(sb.str));
			}
			decl_space.add_type_declaration (new CCodeTypeDefinition ("struct _%s".printf (cname), new CCodeVariableDeclarator (cname)));
			decl_space.add_type_definition (struct_public);
		}
	}


	public override void visit_destructor (Destructor d) {
		unowned Class? cl = d.parent_symbol as Class;
		if (cl == null || !cl.is_supraklass) {
			base.visit_destructor (d);
			return;
		}
		push_line (d.source_reference);

		generate_destructor_function (cl, d);

		pop_line ();
		base.visit_destructor (d);
	}

	private void generate_destructor_function (Class cl, Destructor? d) {
		string cname = get_ccode_name (cl);
		string cname_lower = get_ccode_lower_case_name (cl);

		var finalize_func = new CCodeFunction ("%s_finalize".printf (cname_lower), "void");
		finalize_func.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));
		cfile.add_function_declaration (finalize_func);

		push_function (finalize_func);

		if (d?.body != null) {
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
	}

	public override void visit_creation_method (CreationMethod m) {
		unowned Class? cl = m.parent_symbol as Class;

		if (cl == null && cl.is_supraklass == false) {
			base.visit_creation_method (m);
			return;
		}

		string prefix = get_ccode_lower_case_name (cl);
		string method_suffix = (m.name == ".new") ? "" : "_" + m.name;
		string new_func_name = get_ccode_name (m);
		string init_func_name = "%s_init%s".printf (prefix, method_suffix);


		CCodeFile decl_space = (context.header_filename != null && !cl.is_internal_symbol ()) ? header_file : cfile;

		push_line(m.source_reference);

		string cname = get_ccode_name(cl);

		var function_new = new CCodeFunction(new_func_name, "%s*".printf(cname));

		foreach (var param in m.get_parameters()) {
			function_new.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}

		push_function(function_new);
		var alloc_call = new CCodeFunctionCall(new CCodeIdentifier("malloc"));
		alloc_call.add_argument(new CCodeIdentifier("sizeof (%s)".printf(cname)));
		ccode.add_declaration("%s*".printf(cname), new CCodeVariableDeclarator("self"));
		ccode.add_assignment(new CCodeIdentifier("self"), new CCodeCastExpression(alloc_call, "%s*".printf(cname)));

		var init_call = new CCodeFunctionCall(new CCodeIdentifier(init_func_name));
		init_call.add_argument(new CCodeIdentifier("self"));
		foreach (var param in m.get_parameters()) {
			init_call.add_argument (new CCodeIdentifier (param.name));
		}
		ccode.add_expression(init_call);
		ccode.add_return(new CCodeIdentifier("self"));
		pop_function();


		var init_context = new EmitContext (m);
		push_context (init_context);

		var function_init = new CCodeFunction (init_func_name, "void");
		function_init.add_parameter (new CCodeParameter ("self", "%s*".printf (cname)));

		foreach (Parameter param in m.get_parameters ()) {
			function_init.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}

		push_function (function_init);
		var root_cl = get_root_class (cl);
		var name_root_cl = get_ccode_name (root_cl);


		// set ref_count to 1
		if (cl.base_class == null) {
			var ref_count_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "ref_count");
			ccode.add_assignment (ref_count_access, new CCodeConstant ("1"));
		}
		// priv-> point to the buffer in the struct
		if (cl.has_private_fields) {
			var priv_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv");
			ccode.add_assignment (priv_access, new CCodeCastExpression (new CCodeIdentifier ("self->_priv"), "struct s_%sPrivate*".printf(cname)));
		}

		if (m.body != null) {
			var it = m.body.get_statements ().iterator();
			it.next ();
			Statement first_stat = it.get ();
			bool is_chain_call = false;

			if (first_stat is ExpressionStatement) {
				var expr = ((ExpressionStatement) first_stat).expression;

				if (expr is MethodCall) {
					var mcall = (MethodCall) expr;
					if (mcall.is_chainup) {
						is_chain_call = true;
					}
				}
			}

			if (cl.base_class != null && is_chain_call) {
				first_stat.emit (this);
				init_field_and_vtable (cl, name_root_cl);
			}
			else {
				init_field_and_vtable (cl, name_root_cl);
				first_stat.emit (this);
			}

			while (it.next ()) {
				it.get ().emit (this);
			}
		}

		pop_function ();
		pop_context ();

		pop_line();

		cfile.add_function (function_init);
		cfile.add_function (function_new);
		generate_class_declaration (cl, decl_space);
		decl_space.add_function_declaration (function_init);
		decl_space.add_function_declaration (function_new);
		base.visit_creation_method (m);
	}

	private void init_field_and_vtable (Class cl, string name_root_cl) {
		string vtable_var_name = "%s_VTABLE".printf (get_ccode_upper_case_name (cl));

		var vptr_access = new CCodeMemberAccess.pointer (new CCodeCastExpression (new CCodeIdentifier ("self"), "%s*".printf(name_root_cl)), "vptr");
		ccode.add_assignment (
				vptr_access,
				new CCodeCastExpression (
					new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (vtable_var_name)),
					"const t_%sVtable*".printf (name_root_cl)
					)
				);
		foreach (Field f in cl.get_fields ()) {
			if (f.binding == MemberBinding.INSTANCE) {
				if (f.is_private_symbol ()) {
					var priv_field_access = new CCodeMemberAccess.pointer (
							new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"),
							get_ccode_name (f)
							);
					// TODO set default value if any
					ccode.add_assignment (priv_field_access, new CCodeConstant ("0"));
					continue;
				}
				else {
					var field_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), get_ccode_name (f));
					ccode.add_assignment (field_access, new CCodeConstant ("0"));
				}
			}
		}
	}


	private void generate_supra_vtable_and_init (Class cl, CCodeFile decl_space) {
		define_vtable_struct (cl, decl_space);
		emit_vtable_definition (cl, decl_space);
	}

	private void define_vtable_struct (Class cl, CCodeFile decl_space) {
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

				var sig = new StringBuilder ();
				sig.append ("void*");
				foreach (Parameter param in m.get_parameters ()) {
					sig.append (", ");
					sig.append (get_ccode_name (param.variable_type));
				}

				vtable_struct.add_field (get_ccode_name (m.return_type), "(*%s)(%s)".printf (field_name, sig.str));
			}
		}

		decl_space.add_type_declaration (new CCodeTypeDefinition (
			"struct s_%sVtable".printf (cname),
			new CCodeVariableDeclarator ("t_%sVtable".printf (cname))));
		decl_space.add_type_definition (vtable_struct);
	}

	private void emit_vtable_definition (Class cl, CCodeFile decl_space) {
		string cname = get_ccode_name (cl);
		string cname_lower = get_ccode_lower_case_name (cl);
		string vtable_var_name = "%s_VTABLE".printf (get_ccode_upper_case_name (cl));

		var membres = new StringBuilder ();

		membres.append (".finalize = ");
		membres.append ("(void (*)(void*)) ").append(cname_lower).append("_finalize");
		membres.append (",\n\t\t");

		var base_name_upper = cl.base_class != null ? get_ccode_upper_case_name (cl.base_class) : get_ccode_upper_case_name (cl);
		var base_name = cl.base_class != null ? get_ccode_name (cl.base_class) : get_ccode_name (cl);

		if (cl.base_class != null) {
			membres.append_printf ( "._vala_parent = (const t_%sVtable*) &%s_VTABLE", base_name, base_name_upper);
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

				var sig = new StringBuilder ();
				sig.append ("void*");
				foreach (Parameter param in m_base.get_parameters ()) {
					sig.append (", ");
					sig.append (get_ccode_name (param.variable_type));
				}
				string cast = "(%s (*)(%s)) ".printf (get_ccode_name (m_base.return_type), sig.str);

				// Walk from cl up the hierarchy to find the most-derived
				// implementation (override) of m_base. A class that does not
				// override it inherits the implementation from its parent.
				Method? implementation = null;
				unowned Class? c = cl;
				while (c != null && implementation == null) {
					foreach (Method m_target in c.get_methods()) {
						if (m_target.overrides && m_target.base_method == m_base) {
							implementation = m_target;
							break;
						}
					}
					c = c.base_class;
				}

				if (implementation != null) {
					membres.append ("%s%s".printf(cast, get_ccode_real_name(implementation)));
					// The implementation may live in an ancestor's compilation
					// unit; declare it so this vtable can reference it.
					declare_supra_real_method (implementation, cfile);
				} else if (m_base.is_abstract) {
					membres.append ("NULL");
				} else {
					membres.append ("%s%s".printf(cast, get_ccode_real_name(m_base)));
					declare_supra_real_method (m_base, cfile);
				}
			}
		}

		string ligne_vtable = "const t_%sVtable %s = {\n\t\t%s\n};\n".printf (
				cname,
				vtable_var_name,
				membres.str
		);

		cfile.add_type_member_declaration (new CCodeIdentifier (ligne_vtable));
	}

	private void generate_ref_function (Class cl, CCodeFile decl_space) {
		string cname = get_ccode_name (cl);
		string cname_lower = get_ccode_lower_case_name (cl);

		var ref_func = new CCodeFunction (
				"%s_ref".printf (cname_lower),
				"void*"
				);

		ref_func.add_parameter (new CCodeParameter ("self", "void*"));

		push_function (ref_func);

		var null_check = new CCodeBinaryExpression (
				CCodeBinaryOperator.EQUALITY,
				new CCodeIdentifier ("self"),
				new CCodeConstant ("NULL")
				);

		ccode.open_if (null_check);
		ccode.add_return (new CCodeConstant ("NULL"));
		ccode.close ();

		ccode.add_declaration (
				"%s*".printf (cname),
				new CCodeVariableDeclarator (
					"_self",
					new CCodeCastExpression (
						new CCodeIdentifier ("self"),
						"%s*".printf (cname)
						)
					)
				);

		var inc = new CCodeUnaryExpression (
				CCodeUnaryOperator.POSTFIX_INCREMENT,
				new CCodeMemberAccess.pointer (
					new CCodeIdentifier ("_self"),
					"ref_count"
					)
				);

		ccode.add_expression (inc);
		ccode.add_return (new CCodeIdentifier ("self"));

		pop_function ();

		cfile.add_function (ref_func);
	}

	private void generate_unref_func (Class cl, CCodeFile decl_space) {
		unowned Vala.Class root_cl = get_root_class (cl);
		string cname_lower = get_ccode_lower_case_name (cl);
		string root_name = get_ccode_name (root_cl);

		var unref_func = new CCodeFunction ("%s_unref".printf (cname_lower), "void");
		unref_func.add_parameter (new CCodeParameter ("self", "void*")); 
		push_function (unref_func);

		var self_null = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier ("self"), new CCodeConstant ("NULL"));
		ccode.open_if (self_null);
		ccode.add_return ();
		ccode.close();

		ccode.add_declaration ("%s*".printf (root_name), new CCodeVariableDeclarator ("_self", new CCodeCastExpression (new CCodeIdentifier ("self"), "%s*".printf (root_name))));

		var dec_ref = new CCodeUnaryExpression (CCodeUnaryOperator.PREFIX_DECREMENT, new CCodeMemberAccess.pointer (new CCodeIdentifier ("_self"), "ref_count"));
		var count_zero = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, dec_ref, new CCodeConstant ("0"));

		ccode.open_if (count_zero);
		{
			var vptr_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("_self"), "vptr");
			var finalize_access = new CCodeMemberAccess.pointer (vptr_access, "finalize");
			var finalize_call = new CCodeFunctionCall (finalize_access);
			finalize_call.add_argument (new CCodeIdentifier ("self"));
			ccode.add_expression (finalize_call);

			var free_call = new CCodeFunctionCall (new CCodeIdentifier ("free"));
			free_call.add_argument (new CCodeIdentifier ("self"));
			ccode.add_expression (free_call);
		}
		ccode.close();

		pop_function ();
		cfile.add_function (unref_func);
	}


	public override void visit_method_call (MethodCall expr) {
		if (expr.is_chainup) {
			unowned Method? m = expr.call.symbol_reference as Method;
			if (m != null) {
				unowned Class? cl = m.parent_symbol as Class;
				if (cl != null && cl.is_supraklass) {

					string cname = "%s_init_%s".printf(
						get_ccode_lower_case_name(m.parent_symbol),
						m.name
					);
					var ccall = new CCodeFunctionCall(new CCodeIdentifier(cname));
					var self_cast = new CCodeCastExpression( new CCodeIdentifier("self"), "%s*".printf(get_ccode_name(m.parent_symbol)));
					ccall.add_argument(self_cast);

					foreach (var arg in expr.get_argument_list()) {
						arg.accept(this);
						var arg_c = get_cvalue(arg);
						if (arg_c != null) ccall.add_argument(arg_c);
					}

					ccode.add_expression(ccall);
					set_cvalue(expr, ccall);
					return;
				}
			}
			unowned var cl = expr.call.symbol_reference as Class;
			if (cl != null && cl.is_supraklass) {
				string cname = "%s_init".printf(
						get_ccode_lower_case_name(cl)
						);
				var ccall = new CCodeFunctionCall(new CCodeIdentifier(cname));
				var self_cast = new CCodeCastExpression( new CCodeIdentifier("self"), "%s*".printf(get_ccode_name(cl)));
				ccall.add_argument(self_cast);

				foreach (var arg in expr.get_argument_list()) {
					arg.accept(this);
					var arg_c = get_cvalue(arg);
					if (arg_c != null) ccall.add_argument(arg_c);
				}

				ccode.add_expression(ccall);
				set_cvalue(expr, ccall);
				return;
			}
		}
		var member_access = expr.call as MemberAccess;
		if (member_access != null && member_access.inner is BaseAccess) {
			unowned Method? method = member_access.symbol_reference as Method;
			if (method != null) {
				unowned Class? cl = method.parent_symbol as Class;
				if (cl != null && cl.is_supraklass) {
					// Base acces base->method()
					string cname = "%s_real_%s".printf(
							get_ccode_lower_case_name(method.parent_symbol),
							method.name
							);
					var ccall = new CCodeFunctionCall(new CCodeIdentifier(cname));
					var self_cast = new CCodeCastExpression(
							new CCodeIdentifier("self"),
							"%s*".printf(get_ccode_name(method.parent_symbol))
							);
					ccall.add_argument(self_cast);

					foreach (var arg in expr.get_argument_list()) {
						arg.accept(this);
						var arg_c = get_cvalue(arg);
						if (arg_c != null) ccall.add_argument(arg_c);
					}

					ccode.add_expression(ccall);
					set_cvalue(expr, ccall);
					return;
				}
			}
		}
		base.visit_method_call(expr);
	}

	//////////////////////////////////////////
	////    Declarations
	//////////////////////////////////////////

	private void generate_vtable_declaration (Class cl, CCodeFile decl_space) {
		string cname = get_ccode_name (cl);

		if (add_symbol_declaration (decl_space, cl, "t_%sVtable".printf (cname))) {
			return;
		}

		decl_space.add_type_declaration (new CCodeTypeDefinition (
			"struct s_%sVtable".printf (cname),
			new CCodeVariableDeclarator ("t_%sVtable".printf (cname))
		));
	}

	private void generate_ref_function_declaration (Class cl, CCodeFile decl_space) {
		string cname_lower = get_ccode_lower_case_name (cl);
		var ref_func = new CCodeFunction (
			"%s_ref".printf (cname_lower),
			"void*"
		);

		var unref_func = new CCodeFunction ("%s_unref".printf (cname_lower), "void");
		unref_func.add_parameter (new CCodeParameter ("self", "void*")); 
		decl_space.add_function_declaration (unref_func);
		ref_func.add_parameter (new CCodeParameter ("self", "void*"));
		decl_space.add_function_declaration (ref_func);
	}

}

private unowned Vala.Class get_root_class (Vala.Class cl) {
	unowned Vala.Class root = cl;
	while (root.base_class != null) {
		root = root.base_class;
	}
	return root;
}
