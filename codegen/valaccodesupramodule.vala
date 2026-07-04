/* valaccodesupramodule.vala
 * 
 */

using Vala;

public class Vala.CCodeSupraModule : CCodeSupraErrorModule {

	public override void generate_class_declaration (Class cl, CCodeFile decl_space)
	{
		// The synthetic POSIX Error type is not a real class; it only exists for
		// error member resolution and maps onto t_vala_Error.
		if (context.profile == Profile.POSIX && cl == context.analyzer.gerror_type) {
			return;
		}
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
			add_supra_typeinfo_params (new_func, cl);
			add_supra_typeinfo_params (init_func, cl);
			foreach (Parameter param in m.get_parameters ()) {
				new_func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
				init_func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
			}
			decl_space.add_function_declaration (new_func);
			decl_space.add_function_declaration (init_func);
		}
	}


	public override void visit_class (Class cl) {
		if (context.profile == Profile.POSIX && !cl.is_compact) {
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

		if (cl.has_type_parameters ()) {
			emit_supra_typeinfo_decl (decl_space);
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

		foreach (DataType base_type in cl.get_base_types ()) {
			unowned Interface? iface = base_type.type_symbol as Interface;
			if (iface != null) {
				generate_interface_declaration (iface, decl_space);
				generate_interface_vtable_instance (cl, iface, decl_space);
			}
		}
	}

	//////////////////////////////////////////
	////    Interfaces (fat pointers)
	//////////////////////////////////////////

	// A POSIX interface is represented as a "fat pointer":
	//
	//     typedef struct _IFoo { void* self; const t_IFooVtable* vtable; } IFoo;
	//
	// carrying the instance together with the dispatch table for the concrete
	// class that produced it. Each implementing class exposes a non-static
	// CLASS_IFACE_VTABLE so the wrapping can also happen from another unit.

	public override void visit_interface (Interface iface) {
		if (context.profile != Profile.POSIX) {
			base.visit_interface (iface);
			return;
		}

		iface.set_attribute ("SupraKlass", true);
		iface.is_supraklass = true;

		CCodeFile decl_space;
		if (context.header_filename != null && !iface.is_internal_symbol ()) {
			decl_space = header_file;
			cfile.add_include (Path.get_basename (context.header_filename), true);
		} else {
			decl_space = cfile;
		}

		generate_interface_declaration (iface, decl_space);
		generate_interface_dispatch_wrappers (iface);
		generate_interface_default_methods (iface);

		// Define this interface's runtime identity token; its address is the id.
		declare_interface_id (iface, decl_space);
		if (!cfile.add_declaration ("%s__def".printf (interface_id_name (iface)))) {
			cfile.add_type_member_declaration (new CCodeIdentifier (
				"const char %s = 0;\n".printf (interface_id_name (iface))));
		}
	}

	protected void generate_interface_declaration (Interface iface, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, iface, get_ccode_name (iface))) {
			return;
		}

		decl_space.add_include ("stddef.h");

		string cname = get_ccode_name (iface);

		// vtable type
		decl_space.add_type_declaration (new CCodeTypeDefinition (
			"struct s_%sVtable".printf (cname),
			new CCodeVariableDeclarator ("t_%sVtable".printf (cname))));

		var vtable_struct = new CCodeStruct ("s_%sVtable".printf (cname));
		foreach (Method m in iface.get_methods ()) {
			if (m.binding != MemberBinding.INSTANCE) {
				continue;
			}
			vtable_struct.add_field (get_ccode_name (m.return_type),
				"(*%s)(%s)".printf (get_ccode_vfunc_name (m), interface_vfunc_signature (m)));
		}
		decl_space.add_type_definition (vtable_struct);

		// fat pointer type
		decl_space.add_type_declaration (new CCodeTypeDefinition (
			"struct _%s".printf (cname),
			new CCodeVariableDeclarator (cname)));

		var fat_struct = new CCodeStruct ("_%s".printf (cname));
		fat_struct.add_field ("void*", "self");
		fat_struct.add_field ("const t_%sVtable*".printf (cname), "vtable");
		decl_space.add_type_definition (fat_struct);

		// dispatch wrapper declarations
		foreach (Method m in iface.get_methods ()) {
			if (m.binding != MemberBinding.INSTANCE) {
				continue;
			}
			decl_space.add_function_declaration (interface_dispatch_function (iface, m));
		}
	}

	// The instance is always passed as void* (the fat pointer's self member).
	private string interface_vfunc_signature (Method m) {
		var sig = new StringBuilder ();
		sig.append ("void*");
		foreach (Parameter param in m.get_parameters ()) {
			sig.append (", ");
			sig.append (get_ccode_name (param.variable_type));
		}
		sig.append (supra_error_param_suffix (m));
		return sig.str;
	}

	private CCodeFunction interface_dispatch_function (Interface iface, Method m) {
		var func = new CCodeFunction (get_ccode_name (m), get_ccode_name (m.return_type));
		func.add_parameter (new CCodeParameter ("self", "%s*".printf (get_ccode_name (iface))));
		foreach (Parameter param in m.get_parameters ()) {
			func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}
		add_supra_error_param (func, m);
		return func;
	}

	// ifoo_method (IFoo* self, ...) { return self->vtable->method (self->self, ...); }
	private void generate_interface_dispatch_wrappers (Interface iface) {
		foreach (Method m in iface.get_methods ()) {
			if (m.binding != MemberBinding.INSTANCE) {
				continue;
			}
			var func = interface_dispatch_function (iface, m);
			push_function (func);

			var vtable_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "vtable");
			var method_ptr = new CCodeMemberAccess.pointer (vtable_access, get_ccode_vfunc_name (m));
			var vcall = new CCodeFunctionCall (method_ptr);
			vcall.add_argument (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "self"));
			foreach (Parameter param in m.get_parameters ()) {
				vcall.add_argument (new CCodeIdentifier (param.name));
			}
			if (m.has_error_type_parameter ()) {
				vcall.add_argument (new CCodeIdentifier ("error"));
			}

			if (m.return_type is VoidType) {
				ccode.add_expression (vcall);
			} else {
				ccode.add_return (vcall);
			}
			pop_function ();
			cfile.add_function (func);
		}
	}

	// Default (non-abstract) interface method: "ifoo_real_method".
	private string interface_default_impl_name (Interface iface, Method m) {
		return "%s_real_%s".printf (get_ccode_lower_case_name (iface), m.name);
	}

	private CCodeFunction interface_default_impl_function (Interface iface, Method m) {
		var func = new CCodeFunction (interface_default_impl_name (iface, m), get_ccode_name (m.return_type));
		func.add_parameter (new CCodeParameter ("self", "void*"));
		foreach (Parameter param in m.get_parameters ()) {
			func.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}
		add_supra_error_param (func, m);
		return func;
	}

	private void generate_interface_default_methods (Interface iface) {
		foreach (Method m in iface.get_methods ()) {
			if (m.binding != MemberBinding.INSTANCE || m.is_abstract || m.body == null) {
				continue;
			}
			var func = interface_default_impl_function (iface, m);
			cfile.add_function_declaration (func);

			push_context (new EmitContext (m));
			push_function (func);
			if (!(m.return_type is VoidType) && !m.return_type.is_real_non_null_struct_type ()) {
				ccode.add_declaration (get_ccode_name (m.return_type), new CCodeVariableDeclarator ("result"));
			}
			m.body.accept (this);
			pop_function ();
			pop_context ();
			cfile.add_function (func);
		}
	}

	private void generate_interface_vtable_instance (Class cl, Interface iface, CCodeFile decl_space) {
		string iface_name = get_ccode_name (iface);
		string vtable_var = "%s_%s_VTABLE".printf (
			get_ccode_upper_case_name (cl), get_ccode_upper_case_name (iface));

		decl_space.add_type_member_declaration (new CCodeIdentifier (
			"extern const t_%sVtable %s;\n".printf (iface_name, vtable_var)));

		var membres = new StringBuilder ();
		bool first = true;
		foreach (Method im in iface.get_methods ()) {
			if (im.binding != MemberBinding.INSTANCE) {
				continue;
			}
			if (!first) {
				membres.append (",\n\t\t");
			}
			first = false;

			string cast = "(%s (*)(%s)) ".printf (get_ccode_name (im.return_type), interface_vfunc_signature (im));
			membres.append (".%s = ".printf (get_ccode_vfunc_name (im)));

			Method? impl = find_interface_implementation (cl, im);
			if (impl != null) {
				if ((impl.is_virtual || impl.is_abstract) && !impl.overrides) {
					membres.append ("%s%s".printf (cast, get_ccode_name (impl)));
					generate_method_declaration (impl, cfile);
				} else {
					membres.append ("%s%s".printf (cast, get_ccode_real_name (impl)));
					declare_supra_real_method (impl, cfile);
				}
			} else if (!im.is_abstract && im.body != null) {
				// class does not override it: inherit the interface's default
				membres.append ("%s%s".printf (cast, interface_default_impl_name (iface, im)));
				cfile.add_function_declaration (interface_default_impl_function (iface, im));
			} else {
				membres.append ("NULL");
			}
		}

		string ligne = "const t_%sVtable %s = {\n\t\t%s\n};\n".printf (iface_name, vtable_var, membres.str);
		cfile.add_type_member_declaration (new CCodeIdentifier (ligne));
	}

	// Find the class method that implements an interface method, walking up the
	// hierarchy (an inherited implementation counts).
	private Method? find_interface_implementation (Class cl, Method iface_method) {
		for (unowned Class? c = cl; c != null; c = c.base_class) {
			foreach (Method m in c.get_methods ()) {
				if (m.base_interface_method == iface_method) {
					return m;
				}
			}
		}
		// fall back to matching by name (implicit implementation)
		for (unowned Class? c = cl; c != null; c = c.base_class) {
			foreach (Method m in c.get_methods ()) {
				if (m.name == iface_method.name) {
					return m;
				}
			}
		}
		return null;
	}

	//////////////////////////////////////////
	////    Runtime interface checks (obj is IFoo)
	//////////////////////////////////////////

	// Interfaces are identified by their (fully-qualified, hence unique) C name
	// rather than by a global identity symbol: comparing string contents is
	// robust across shared objects, whereas address identity of a dummy token
	// is not (symbol interposition / duplicate definitions between .so).

	// Each interface owns a unique global token; its address is its identity.
	// Resolved once by the dynamic linker, so a plain pointer equality is safe
	// across shared objects (no numeric registry, no strcmp).
	//
	//     extern const char IFOO_INTERFACE_ID;   // const char IFOO_INTERFACE_ID = 0;
	protected string interface_id_name (Interface iface) {
		return "%s_INTERFACE_ID".printf (get_ccode_upper_case_name (iface));
	}

	protected void declare_interface_id (Interface iface, CCodeFile decl_space) {
		if (decl_space.add_declaration (interface_id_name (iface))) {
			return;
		}
		decl_space.add_type_member_declaration (new CCodeIdentifier (
			"extern const char %s;\n".printf (interface_id_name (iface))));
	}

	// typedef struct { const void* interface_id; const void* vtable; } t_vala_InterfaceEntry;
	private void ensure_interface_entry_type () {
		if (!add_wrapper ("t_vala_InterfaceEntry")) {
			return;
		}
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"typedef struct { const void* interface_id; const void* vtable; } t_vala_InterfaceEntry;\n"));
	}

	// static const t_vala_InterfaceEntry CLASS_INTERFACES[] = {
	//     { &IFOO_INTERFACE_ID, &CLASS_IFOO_VTABLE }, { NULL, NULL } };
	// Each entry maps an interface identity to the class' concrete interface
	// vtable, so the same table powers both `is` and a dynamic interface cast.
	private string emit_class_interface_table (Class cl, CCodeFile decl_space) {
		var entries = new StringBuilder ();
		foreach (DataType base_type in cl.get_base_types ()) {
			unowned Interface? iface = base_type.type_symbol as Interface;
			if (iface == null) {
				continue;
			}
			generate_interface_declaration (iface, decl_space);
			declare_interface_id (iface, decl_space);
			string iface_vtable = "%s_%s_VTABLE".printf (
				get_ccode_upper_case_name (cl), get_ccode_upper_case_name (iface));
			cfile.add_type_member_declaration (new CCodeIdentifier (
				"extern const t_%sVtable %s;\n".printf (get_ccode_name (iface), iface_vtable)));
			entries.append_printf ("{ &%s, &%s }, ", interface_id_name (iface), iface_vtable);
		}
		if (entries.len == 0) {
			return "NULL";
		}
		ensure_interface_entry_type ();
		string table_var = "%s_INTERFACES".printf (get_ccode_upper_case_name (cl));
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"static const t_vala_InterfaceEntry %s[] = { %s{ NULL, NULL } };\n".printf (table_var, entries.str)));
		return table_var;
	}

	// Emitted once per compilation unit that needs it: walk the vptr/_vala_parent
	// chain and look the interface identity up by pointer equality. Returns the
	// concrete interface vtable (for a fat-pointer cast) or NULL. The header
	// struct mirrors the common prefix of every t_*Vtable.
	protected void emit_interface_is_a_helper () {
		if (!add_wrapper ("_vala_get_interface")) {
			return;
		}
		ensure_interface_entry_type ();
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"""typedef struct { void (*finalize)(void*); const void* _vala_parent; const void* _vala_interfaces; } t_vala_VtableHeader;
static const void* _vala_get_interface (void* obj, const void* interface_id) {
	const t_vala_VtableHeader* v;
	const t_vala_InterfaceEntry* it;
	if (obj == NULL) {
		return NULL;
	}
	v = *((const t_vala_VtableHeader* const*) obj);
	while (v != NULL) {
		it = (const t_vala_InterfaceEntry*) v->_vala_interfaces;
		if (it != NULL) {
			for (; it->interface_id != NULL; it++) {
				if (it->interface_id == interface_id) {
					return it->vtable;
				}
			}
		}
		v = (const t_vala_VtableHeader*) v->_vala_parent;
	}
	return NULL;
}
"""));
	}

	// obj is IFoo  ->  _vala_get_interface (obj, &IFOO_INTERFACE_ID) != NULL
	// Error instances are plain t_vala_Error*; map member access (e.message /
	// e.code / e.domain) straight onto the struct fields. This also keeps the
	// synthetic POSIX Error type (see SemanticAnalyzer) out of codegen entirely.
	public override void visit_member_access (MemberAccess expr) {
		if (context.profile == Profile.POSIX && expr.inner != null
		    && expr.inner.value_type is ErrorType
		    && expr.symbol_reference is Field) {
			emit_supra_error_runtime ();
			expr.inner.accept (this);
			var obj = new CCodeCastExpression (get_cvalue (expr.inner), "t_vala_Error*");
			set_cvalue (expr, new CCodeMemberAccess.pointer (obj, expr.symbol_reference.name));
			return;
		}
		base.visit_member_access (expr);
	}

	public override void visit_type_check (TypeCheck expr) {
		// `e is MyError[.CODE]`: compare the flat t_vala_Error fields directly
		// (domain by address, optionally code), no g_error_matches / GLib.
		unowned ErrorType? et = expr.type_reference as ErrorType;
		if (context.profile == Profile.POSIX && et != null && et.error_domain == null) {
			// `e is Error`: every error value is an instance of the base error type.
			set_cvalue (expr, new CCodeConstant ("1"));
			return;
		}
		if (context.profile == Profile.POSIX && et != null && et.error_domain != null) {
			emit_supra_error_runtime ();
			generate_error_domain_declaration (et.error_domain, cfile);
			CCodeExpression obj = get_cvalue (expr.expression);
			CCodeExpression check = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY,
				new CCodeMemberAccess.pointer (obj, "domain"),
				new CCodeIdentifier (get_ccode_upper_case_name (et.error_domain)));
			if (et.error_code != null) {
				check = new CCodeBinaryExpression (CCodeBinaryOperator.AND, check,
					new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY,
						new CCodeMemberAccess.pointer (obj, "code"),
						new CCodeIdentifier (get_ccode_name (et.error_code))));
			}
			set_cvalue (expr, check);
			return;
		}

		if (context.profile != Profile.POSIX || !(expr.type_reference.type_symbol is Interface)) {
			base.visit_type_check (expr);
			return;
		}

		unowned Interface iface = (Interface) expr.type_reference.type_symbol;
		generate_interface_declaration (iface, cfile);
		declare_interface_id (iface, cfile);
		emit_interface_is_a_helper ();

		CCodeExpression obj = get_cvalue (expr.expression);
		// A fat-pointer source carries the real object in its self member.
		unowned DataType? expr_type = expr.expression.value_type;
		if (expr_type != null && expr_type.type_symbol is Interface) {
			obj = new CCodeMemberAccess.pointer (obj, "self");
		}

		var call = new CCodeFunctionCall (new CCodeIdentifier ("_vala_get_interface"));
		call.add_argument (new CCodeCastExpression (obj, "void*"));
		call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
			new CCodeIdentifier (interface_id_name (iface))));
		set_cvalue (expr, new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY,
			call, new CCodeConstant ("NULL")));
	}

	protected unowned Class supra_interface_impl_class (Class cl, Interface iface) {
		unowned Class? c = cl;
		while (c != null) {
			foreach (DataType base_type in c.get_base_types ()) {
				if (base_type.type_symbol == iface) {
					return c;
				}
			}
			c = c.base_class;
		}
		return cl;
	}


	protected CCodeExpression build_supra_fat_pointer (Class cl, Interface iface, CCodeExpression cexpr) {
		generate_interface_declaration (iface, cfile);
		generate_class_declaration (cl, cfile);

		unowned Class impl_cl = supra_interface_impl_class (cl, iface);

		string vtable_var = "%s_%s_VTABLE".printf (
			get_ccode_upper_case_name (impl_cl), get_ccode_upper_case_name (iface));
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"extern const t_%sVtable %s;\n".printf (get_ccode_name (iface), vtable_var)));

		var init = new CCodeInitializerList ();
		init.append (new CCodeCastExpression (cexpr, "void*"));
		init.append (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (vtable_var)));
		// &(IFoo){ ... } : interface values are pointers to the fat-pointer struct
		var literal = new CCodeCastExpression (init, get_ccode_name (iface));
		return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, literal);
	}

	private bool is_supra_interface_type (DataType? type) {
		return context.profile == Profile.POSIX
		    && type != null && type.type_symbol is Interface;
	}

	public override TargetValue? copy_value (TargetValue value, CodeNode node) {
		if (is_supra_interface_type (value.value_type)) {
			return ((GLibValue) value).copy ();
		}
		return base.copy_value (value, node);
	}

	public override CCodeExpression destroy_value (TargetValue value, bool is_macro_definition = false) {
		if (is_supra_interface_type (value.value_type)) {
			if (value.value_type != null && value.value_type.value_owned) {
				emit_supra_object_unref_helper ();
				var unref_call = new CCodeFunctionCall (new CCodeIdentifier ("_vala_supra_object_unref"));
				unref_call.add_argument (new CCodeMemberAccess.pointer (get_cvalue_ (value), "self"));
				return unref_call;
			}
			return new CCodeConstant ("((void) 0)");
		}
		return base.destroy_value (value, is_macro_definition);
	}

	private void emit_vala_atomic_helpers () {
		if (!add_wrapper ("vala_atomic")) {
			return;
		}
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"""#ifdef _MSC_VER
#include <intrin.h>
static inline int vala_atomic_inc (int* p) { return _InterlockedIncrement ((long volatile*) p); }
static inline int vala_atomic_dec_and_test (int* p) { return _InterlockedDecrement ((long volatile*) p) == 0; }
#else
static inline int vala_atomic_inc (int* p) { return __atomic_add_fetch (p, 1, __ATOMIC_SEQ_CST); }
static inline int vala_atomic_dec_and_test (int* p) { return __atomic_sub_fetch (p, 1, __ATOMIC_SEQ_CST) == 0; }
#endif
"""));
	}

	private void emit_supra_object_unref_helper () {
		if (!add_wrapper ("_vala_supra_object_unref")) {
			return;
		}
		emit_vala_atomic_helpers ();
		cfile.add_type_member_declaration (new CCodeIdentifier (
			"""static inline void _vala_supra_object_unref (void* self) {
	struct _supra_vtable { void (*finalize)(void*); };
	struct _supra_object { const struct _supra_vtable* vptr; int ref_count; };
	struct _supra_object* _self;
	if (self == NULL) {
		return;
	}
	_self = (struct _supra_object*) self;
	if (vala_atomic_dec_and_test (&_self->ref_count)) {
		_self->vptr->finalize (self);
		free (self);
	}
}"""));
	}

	public override void visit_cast_expression (CastExpression expr) {
		unowned Interface? iface = expr.target_type != null ? expr.target_type.type_symbol as Interface : null;
		if (context.profile == Profile.POSIX && iface != null) {
			expr.inner.accept (this);
			unowned Class? cl = expr.inner.value_type.type_symbol as Class;
			if (cl != null && cl.is_supraklass) {
				set_cvalue (expr, build_supra_fat_pointer (cl, iface, get_cvalue (expr.inner)));
			} else {
				set_cvalue (expr, get_cvalue (expr.inner));
			}
			return;
		}

		var sym = expr.target_type != null ? expr.target_type.type_symbol : null;
		if (expr.inner is MemberAccess) {
			var ma = expr.inner as MemberAccess;
			if (ma.symbol_reference is Field) {
				var field = ma.symbol_reference as Field;
				if (field.is_private_symbol()) {
					base.visit_cast_expression(expr);
					return;
				}
			}
		}
		unowned Class? target_cl = sym as Class;
		if (target_cl == null || !target_cl.is_supraklass) {
			base.visit_cast_expression(expr);
			return;
		}

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

	public override void visit_method (Method m) {
		// interface methods are emitted as dispatch wrappers by visit_interface
		if (context.profile == Profile.POSIX && m.parent_symbol is Interface) {
			return;
		}

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
				add_supra_error_param (func, m);
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
		add_supra_error_param (func, m);
		decl_space.add_function_declaration (func);
	}

	// In the POSIX profile a throwing method takes a trailing "t_vala_Error**
	// error" out-parameter (the GLib-free analogue of GError**). The supra
	// backend builds parameter lists by hand, so this is appended explicitly
	// everywhere a method signature is emitted.
	private void add_supra_error_param (CCodeFunction func, Method m) {
		if (m.has_error_type_parameter ()) {
			func.add_parameter (new CCodeParameter ("error", "t_vala_Error**"));
		}
	}

	private string supra_error_param_suffix (Method m) {
		return m.has_error_type_parameter () ? ", t_vala_Error**" : "";
	}

	private void generate_supra_real_method (Method m) {
		unowned Class cl = (Class) m.parent_symbol;
		string real_name = get_ccode_real_name(m);

		var func_wrapper = new CCodeFunction (real_name, get_ccode_name (m.return_type));
		func_wrapper.add_parameter (new CCodeParameter ("self", "%s*".printf (get_ccode_name (cl))));

		// A creation method's _construct runs in in-creation context, where a
		// type parameter resolves to the incoming t_TypeInfo* param (not priv).
		if (m is CreationMethod) {
			add_supra_typeinfo_params (func_wrapper, cl);
		}
		foreach (Parameter param in m.get_parameters ()) {
			func_wrapper.add_parameter (new CCodeParameter (param.name, get_ccode_name (param.variable_type)));
		}
		add_supra_error_param (func_wrapper, m);

		cfile.add_function_declaration (func_wrapper);

		push_function (func_wrapper);

		if (!(m.return_type is VoidType) && !m.return_type.is_real_non_null_struct_type ()) {
			ccode.add_declaration (get_ccode_name (m.return_type), new CCodeVariableDeclarator ("result"));
		}

		if (m.body != null) {
			m.body.accept (this);
		}

		if (current_method_inner_error) {
			ccode.add_declaration (get_inner_error_ctype (), new CCodeVariableDeclarator.zero ("_inner_error%d_".printf (current_inner_error_id), new CCodeConstant ("NULL")));
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
		add_supra_error_param (wrapper_func, m);

		push_function (wrapper_func);

		var vtable_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("base"), "vptr");
		var method_ptr = new CCodeMemberAccess.pointer (vtable_access, get_ccode_vfunc_name (m));

		var vcall = new CCodeFunctionCall (method_ptr);
		vcall.add_argument (new CCodeIdentifier ("base"));

		foreach (Parameter param in m.get_parameters ()) {
			vcall.add_argument (new CCodeIdentifier (param.name));
		}
		if (m.has_error_type_parameter ()) {
			vcall.add_argument (new CCodeIdentifier ("error"));
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

	// POSIX erased generics: the per-instance t_TypeInfo* descriptor names for a
	// generic class (one per type parameter), stored in the private struct and
	// threaded through the constructor in place of GObject's type/dup/destroy triple.
	private string[] supra_typeinfo_names (Class cl) {
		string[] names = {};
		foreach (var tp in cl.get_type_parameters ()) {
			names += "%s_typeinfo".printf (tp.name.ascii_down ());
		}
		return names;
	}

	private unowned Interface? supra_constraint_iface (TypeParameter tp) {
		return tp.constraint_type != null ? tp.constraint_type.type_symbol as Interface : null;
	}

	// All per-instance erased-generic descriptors threaded through the ctor and
	// stored in priv: each type parameter's t_TypeInfo* plus, when constrained,
	// its interface witness vtable. Order matches add_supra_typeinfo_params.
	private string[] supra_generic_names (Class cl) {
		string[] names = {};
		foreach (var tp in cl.get_type_parameters ()) {
			names += "%s_typeinfo".printf (tp.name.ascii_down ());
			if (supra_constraint_iface (tp) != null) {
				names += "%s_witness".printf (tp.name.ascii_down ());
			}
		}
		return names;
	}

	// "const t_TypeInfo* g_typeinfo;const t_IFooVtable* g_witness;..." for the
	// private struct and its in-instance sizing mirror.
	private string supra_generic_field_decls (Class cl) {
		var sb = new StringBuilder ();
		foreach (var tp in cl.get_type_parameters ()) {
			sb.append_printf ("const t_TypeInfo* %s_typeinfo;", tp.name.ascii_down ());
			unowned Interface? iface = supra_constraint_iface (tp);
			if (iface != null) {
				sb.append_printf ("const t_%sVtable* %s_witness;", get_ccode_name (iface), tp.name.ascii_down ());
			}
		}
		return sb.str;
	}

	private void add_supra_typeinfo_params (CCodeFunction func, Class cl) {
		foreach (var tp in cl.get_type_parameters ()) {
			func.add_parameter (new CCodeParameter ("%s_typeinfo".printf (tp.name.ascii_down ()), "const t_TypeInfo*"));
			unowned Interface? iface = supra_constraint_iface (tp);
			if (iface != null) {
				func.add_parameter (new CCodeParameter ("%s_witness".printf (tp.name.ascii_down ()), "const t_%sVtable*".printf (get_ccode_name (iface))));
			}
		}
	}

	private void generate_private_struct_declaration (Class cl, CCodeFile decl_space) {
		if (!cl.has_private_fields && !cl.has_type_parameters ()) {
			return;
		}
		string cname = get_ccode_name (cl);

		// private struct
		var private_struct = new CCodeStruct ("s_%sPrivate".printf (cname));
		foreach (Field f in cl.get_fields ()) {
			if (f.is_private_symbol ()) {
				append_field (private_struct, f, decl_space);
			}
		}
		foreach (var tp in cl.get_type_parameters ()) {
			private_struct.add_field ("const t_TypeInfo*", "%s_typeinfo".printf (tp.name.ascii_down ()));
			unowned Interface? iface = supra_constraint_iface (tp);
			if (iface != null) {
				private_struct.add_field ("const t_%sVtable*".printf (get_ccode_name (iface)), "%s_witness".printf (tp.name.ascii_down ()));
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
				struct_public.add_field ("int", "ref_count");
			} else {
				struct_public.add_field (get_ccode_name (cl.base_class), "parent");
			}

			foreach (Field f in cl.get_fields ()) {
				if (f.binding == MemberBinding.INSTANCE && !f.is_private_symbol ()) {
					append_field (struct_public, f, decl_space);
				}
			}
			if (cl.has_private_fields || cl.has_type_parameters ()) {
				StringBuilder sb = new StringBuilder();
				sb.append("struct {");
				foreach (Field f in cl.get_fields ()) {
					if (f.is_private_symbol ()) {
						sb.append_printf("%s %s;", get_ccode_name (f.variable_type), get_ccode_name (f));
						if (f.variable_type is ArrayType && get_ccode_array_length (f)) {
							var array_type = (ArrayType) f.variable_type;
							if (!array_type.fixed_length) {
								var length_ctype = get_ccode_array_length_type (f);
								for (int dim = 1; dim <= array_type.rank; dim++) {
									sb.append_printf("%s %s;", length_ctype, get_variable_array_length_cname (f, dim));
								}
								if (array_type.rank == 1 && f.is_internal_symbol ()) {
									sb.append_printf("%s %s;", length_ctype, get_array_size_cname (get_ccode_name (f)));
								}
							}
						}
					}
				}
				sb.append (supra_generic_field_decls (cl));
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
		// establish the class as current symbol so a generic field's destroy
		// resolves to self->priv-><T>_typeinfo->free (is_in_generic_type).
		emit_context.push_symbol (cl);

		if (d?.body != null) {
			d.body.accept (this);
		}

		bool needs_priv = false;
		foreach (Field f in cl.get_fields ()) {
			if (f.binding != MemberBinding.INSTANCE) {
				continue;
			}
			if ((!(f.variable_type is DelegateType) || get_ccode_delegate_target (f)) && requires_destroy (f.variable_type)) {
				if (f.is_private_symbol ()) {
					needs_priv = true;
				}
			}
		}
		if (needs_priv) {
			var priv_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv");
			ccode.add_assignment (priv_access, new CCodeCastExpression (new CCodeIdentifier ("self->_priv"), "struct s_%sPrivate*".printf (cname)));
		}
		var this_type = SemanticAnalyzer.get_data_type_for_symbol (cl);
		var instance = new GLibValue (this_type, new CCodeIdentifier ("self"), true);
		foreach (Field f in cl.get_fields ()) {
			if (f.binding != MemberBinding.INSTANCE) {
				continue;
			}
			if ((!(f.variable_type is DelegateType) || get_ccode_delegate_target (f)) && requires_destroy (f.variable_type)) {
				ccode.add_expression (destroy_field (f, instance));
			}
		}

		if (cl.base_class != null) {
			var parent_cname_lower = get_ccode_lower_case_name (cl.base_class);
			var parent_finalize = new CCodeFunctionCall (new CCodeIdentifier ("%s_finalize".printf (parent_cname_lower)));
			parent_finalize.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "%s*".printf (get_ccode_name (cl.base_class))));
			ccode.add_expression (parent_finalize);
		}

		emit_context.pop_symbol ();
		pop_function ();
		cfile.add_function (finalize_func);
	}

	public override void visit_field (Field f) {
		unowned Class? cl = f.parent_symbol as Class;
		// Instance fields of a supraklass are part of the generated struct and
		// their initializers are emitted in init_field_and_vtable(). Base
		// visit_field() would push the GObject instance_init_context, which is
		// null under --profile=posix and would crash.
		if (cl != null && cl.is_supraklass && f.binding == MemberBinding.INSTANCE) {
			return;
		}
		base.visit_field (f);
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

		add_supra_typeinfo_params (function_new, cl);
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
		foreach (var name in supra_generic_names (cl)) {
			init_call.add_argument (new CCodeIdentifier (name));
		}
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

		add_supra_typeinfo_params (function_init, cl);
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
		if (cl.has_private_fields || cl.has_type_parameters ()) {
			var priv_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv");
			ccode.add_assignment (priv_access, new CCodeCastExpression (new CCodeIdentifier ("self->_priv"), "struct s_%sPrivate*".printf(cname)));
		}
		// store the erased-generic descriptors into the instance
		foreach (var name in supra_generic_names (cl)) {
			var priv_field = new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), name);
			ccode.add_assignment (priv_field, new CCodeIdentifier (name));
		}

		unowned List<Statement>? statements = (m.body != null) ? m.body.get_statements () : null;
		Statement? first_stat = (statements != null && statements.size > 0) ? statements.get (0) : null;

		bool is_chain_call = false;
		if (first_stat is ExpressionStatement) {
			var expr = ((ExpressionStatement) first_stat).expression;
			if (expr is MethodCall && ((MethodCall) expr).is_chainup) {
				is_chain_call = true;
			}
		}

		if (cl.base_class != null && is_chain_call) {
			first_stat.emit (this);
			init_field_and_vtable (cl, name_root_cl);
			for (int i = 1; i < statements.size; i++) {
				statements.get (i).emit (this);
			}
		} else {
			init_field_and_vtable (cl, name_root_cl);
			if (statements != null) {
				foreach (Statement stat in statements) {
					stat.emit (this);
				}
			}
		}

		if (m.body != null) {
			var local_vars = m.body.get_local_variables ();
			for (int i = local_vars.size - 1; i >= 0; i--) {
				var local = local_vars[i];
				local.active = false;
				if (!local.unreachable && !local.captured && requires_destroy (local.variable_type)) {
					ccode.add_expression (destroy_local (local));
				}
			}
		}

		// Free owned parameters that were not consumed by the body.
		foreach (Parameter param in m.get_parameters ()) {
			if (!param.captured && !param.ellipsis && !param.params_array
			    && param.direction == ParameterDirection.IN
			    && requires_destroy (param.variable_type)) {
				ccode.add_expression (destroy_parameter (param));
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
			if (f.binding != MemberBinding.INSTANCE) {
				continue;
			}

			CCodeExpression field_access;
			if (f.is_private_symbol ()) {
				field_access = new CCodeMemberAccess.pointer (
						new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"),
						get_ccode_name (f)
						);
			} else {
				field_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), get_ccode_name (f));
			}

			if (f.initializer != null) {
				f.initializer.emit (this);
				ccode.add_assignment (field_access, get_cvalue (f.initializer));
			} else {
				ccode.add_assignment (field_access, new CCodeConstant ("0"));
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
		// Pointer to this class' NULL-terminated t_vala_InterfaceEntry table
		// (kept opaque here so the vtable struct needs no extra type), used by
		// `obj is IFoo` / interface casts (see emit_interface_is_a_helper).
		vtable_struct.add_field ("const void*", "_vala_interfaces");

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
				sig.append (supra_error_param_suffix (m));

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

		// Directly-implemented interfaces: emit a NULL-terminated table of their
		// identity tokens and point the vtable at it. Inherited interfaces are
		// reached by walking _vala_parent at runtime.
		membres.append (",\n\t\t._vala_interfaces = ");
		membres.append (emit_class_interface_table (cl, decl_space));

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
				sig.append (supra_error_param_suffix (m_base));
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

		emit_vala_atomic_helpers ();
		var inc = new CCodeFunctionCall (new CCodeIdentifier ("vala_atomic_inc"));
		inc.add_argument (new CCodeUnaryExpression (
				CCodeUnaryOperator.ADDRESS_OF,
				new CCodeMemberAccess.pointer (
					new CCodeIdentifier ("_self"),
					"ref_count"
					)
				));

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

		emit_vala_atomic_helpers ();
		var count_zero = new CCodeFunctionCall (new CCodeIdentifier ("vala_atomic_dec_and_test"));
		count_zero.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeMemberAccess.pointer (new CCodeIdentifier ("_self"), "ref_count")));

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
