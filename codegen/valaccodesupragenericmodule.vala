/* valaccodesupragenericmodule.vala
 *
 * Head of the POSIX (supra) codegen chain. Isolates erased-generic and
 * type-parameter-constraint handling: t_TypeInfo threading, auto duck-typed
 * interface witnesses, typeof, and the generic-aware implicit cast. The
 * concrete class the compiler instantiates for --profile=posix.
 */

using Vala;

public class Vala.CCodeSupraGenericModule : CCodeSupraModule {

	// Constrained erased generic (`<G : IFoo>`): the value is the raw object
	// payload, not a fat pointer. Build one on the fly, resolving the concrete
	// class's interface vtable at runtime by walking its vptr chain.
	private CCodeExpression build_supra_dynamic_fat_pointer (Interface iface, CCodeExpression cexpr) {
		generate_interface_declaration (iface, cfile);
		declare_interface_id (iface, cfile);
		emit_interface_is_a_helper ();

		var lookup = new CCodeFunctionCall (new CCodeIdentifier ("_vala_get_interface"));
		lookup.add_argument (new CCodeCastExpression (cexpr, "void*"));
		lookup.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
			new CCodeIdentifier (interface_id_name (iface))));

		var init = new CCodeInitializerList ();
		init.append (new CCodeCastExpression (cexpr, "void*"));
		init.append (new CCodeCastExpression (lookup, "const t_%sVtable*".printf (get_ccode_name (iface))));
		var literal = new CCodeCastExpression (init, get_ccode_name (iface));
		return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, literal);
	}

	// Build a fat pointer for a constrained erased generic from the witness
	// vtable threaded in alongside the t_TypeInfo: (IFoo){ (void*) g, g_witness }.
	private CCodeExpression build_supra_witness_fat_pointer (Interface iface, CCodeExpression cexpr, CCodeExpression witness) {
		generate_interface_declaration (iface, cfile);
		var init = new CCodeInitializerList ();
		init.append (new CCodeCastExpression (cexpr, "void*"));
		init.append (new CCodeCastExpression (witness, "const t_%sVtable*".printf (get_ccode_name (iface))));
		var literal = new CCodeCastExpression (init, get_ccode_name (iface));
		return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, literal);
	}

	// The erased ABI bit-packs integral values into the void* payload; strings
	// and objects are the pointer itself.
	private bool supra_is_packed_value (DataType type) {
		return !get_ccode_name (type).has_suffix ("*");
	}

	// Unpack the erased void* payload back to the concrete C type inside a
	// witness adapter: (gint)(intptr_t) self for integrals, (Foo*) self else.
	private CCodeExpression supra_unpack_self (DataType concrete) {
		CCodeExpression self = new CCodeIdentifier ("self");
		if (supra_is_packed_value (concrete)) {
			self = new CCodeCastExpression (self, intptr_ctype ());
		}
		return new CCodeCastExpression (self, get_ccode_name (concrete));
	}

	// Auto (duck-typed) witness: a per-(concrete, interface) vtable whose slots
	// are adapters unpacking the erased self and calling the concrete type's
	// matching method. Emitted once; returns the vtable's C identifier.
	private string emit_supra_constraint_witness (DataType concrete, Interface iface) {
		string csan = get_ccode_name (concrete).replace ("*", "").replace (" ", "_");
		string vtable_var = "_witness_%s_%s".printf (csan, get_ccode_name (iface));
		if (!add_wrapper (vtable_var)) {
			return vtable_var;
		}
		generate_interface_declaration (iface, cfile);

		var slots = new StringBuilder ();
		foreach (Method m in iface.get_methods ()) {
			if (m.binding != MemberBinding.INSTANCE) {
				continue;
			}
			Method? cm = concrete.get_member (m.name) as Method;
			generate_method_declaration (cm, cfile);
			if (!cm.external && cm.external_package && add_generated_external_symbol (cm)) {
				visit_method (cm);
			}
			string adapter = "%s_%s".printf (vtable_var, get_ccode_vfunc_name (m));

			var proto = new StringBuilder ();
			proto.append ("static %s %s (void* self".printf (get_ccode_name (m.return_type), adapter));
			foreach (Parameter param in m.get_parameters ()) {
				proto.append (", %s %s".printf (get_ccode_name (param.variable_type), param.name));
			}
			proto.append (");\n");
			cfile.add_type_member_declaration (new CCodeIdentifier (proto.str));

			var func = new CCodeFunction (adapter, get_ccode_name (m.return_type));
			func.modifiers |= CCodeModifiers.STATIC;
			func.add_parameter (new CCodeParameter ("self", "void*"));
			foreach (Parameter param in m.get_parameters ()) {
				func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
			}
			push_function (func);

			var call = new CCodeFunctionCall (new CCodeIdentifier (get_ccode_name (cm)));
			call.add_argument (supra_unpack_self (concrete));
			foreach (Parameter param in m.get_parameters ()) {
				call.add_argument (new CCodeIdentifier (param.name));
			}
			if (get_ccode_name (m.return_type) == "void") {
				ccode.add_expression (call);
			} else {
				CCodeExpression ret = call;
				// Bridge ownership: the interface contract returns owned, but the
				// concrete method may hand back an unowned reference (e.g. the
				// string identity `to_string`); copy it so the caller can free it.
				if (m.return_type.value_owned && !cm.return_type.value_owned && requires_copy (m.return_type)) {
					var cp = new CCodeFunctionCall (new CCodeIdentifier (get_ccode_copy_function (cm.return_type.type_symbol)));
					cp.add_argument (call);
					ret = cp;
				}
				ccode.add_return (ret);
			}
			pop_function ();
			cfile.add_function (func);

			if (slots.len > 0) {
				slots.append (", ");
			}
			slots.append (adapter);
		}
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"static const t_%sVtable %s = { %s };\n".printf (get_ccode_name (iface), vtable_var, slots.str)));
		return vtable_var;
	}

	protected override CCodeExpression? get_supra_constraint_witness_argument (DataType type_arg, TypeParameter type_param, bool is_chainup) {
		unowned Interface? iface = type_param.constraint_type.type_symbol as Interface;
		if (iface == null) {
			return null;
		}
		if (type_arg is GenericType) {
			// forwarding an enclosing constrained parameter: pass its witness through
			var name = "%s_witness".printf (((GenericType) type_arg).type_parameter.name.ascii_down ());
			return get_generic_type_expression (name, (GenericType) type_arg, is_chainup);
		}
		// A class that nominally implements the interface already has a per-class
		// interface vtable emitted; reuse it instead of synthesizing an adapter.
		unowned Class? cl = type_arg.type_symbol as Class;
		if (cl != null && cl.is_supraklass && type_arg.type_symbol.is_subtype_of (iface)) {
			generate_class_declaration (cl, cfile);
			generate_interface_declaration (iface, cfile);
			unowned Class impl = supra_interface_impl_class (cl, iface);
			string vtable_var = "%s_%s_VTABLE".printf (
				get_ccode_upper_case_name (impl), get_ccode_upper_case_name (iface));
			cfile.add_type_member_declaration (new CCodeIdentifier (
				"extern const t_%sVtable %s;\n".printf (get_ccode_name (iface), vtable_var)));
			return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (vtable_var));
		}
		return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
			new CCodeIdentifier (emit_supra_constraint_witness (type_arg, iface)));
	}

	public override CCodeExpression get_implicit_cast_expression (CCodeExpression source_cexpr, DataType? expression_type, DataType? target_type, CodeNode? node) {
		if (context.profile == Profile.POSIX && target_type != null
		    && target_type.type_symbol == context.analyzer.gerror_type) {
			// Both ErrorType and the synthetic Error class are t_vala_Error*; no
			// cast needed (and casting would drag the synthetic class into codegen).
			return source_cexpr;
		}
		if (context.profile == Profile.POSIX && expression_type != null && target_type != null) {
			unowned Interface? iface = target_type.type_symbol as Interface;
			if (iface != null) {
				if (expression_type is GenericType) {
					unowned GenericType gt = (GenericType) expression_type;
					if (gt.type_parameter.constraint_type != null) {
						var wname = "%s_witness".printf (gt.type_parameter.name.ascii_down ());
						return build_supra_witness_fat_pointer (iface, source_cexpr, get_generic_type_expression (wname, gt));
					}
					return build_supra_dynamic_fat_pointer (iface, source_cexpr);
				}
				unowned Class? cl = expression_type.type_symbol as Class;
				if (cl != null && cl.is_supraklass) {
					return build_supra_fat_pointer (cl, iface, source_cexpr);
				}
				if (expression_type.type_symbol == iface) {
					// already a fat pointer of the same interface
					return source_cexpr;
				}
			}
		}
		return base.get_implicit_cast_expression (source_cexpr, expression_type, target_type, node);
	}

	// Fat pointers are not reference-counted in the POSIX profile (they only
	// borrow the instance), so copying one is just copying the pointer and
	// destroying one is a no-op. This also bypasses the GObject-oriented
	// "missing class prerequisite" diagnostic for prerequisite-less interfaces.

	public override void visit_typeof_expression (TypeofExpression expr) {
		if (context.profile == Profile.POSIX) {
			CCodeExpression e;
			if (expr.type_reference is GenericType) {
				e = get_supra_typeinfo_expression ((GenericType) expr.type_reference);
			} else {
				unowned Class? cl = expr.type_reference.type_symbol as Class;
				if (cl != null && cl.is_supraklass) {
					generate_class_declaration (cl, cfile);
				}
				e = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
					new CCodeIdentifier (get_supra_typeinfo (expr.type_reference)));
			}
			set_cvalue (expr, new CCodeCastExpression (e, "const void*"));
			return;
		}
		base.visit_typeof_expression (expr);
	}

}
