/* valaccodesupraweakrefmodule.vala
 *
 * Auto-nulling weak references (the `weakref` soft keyword) for the POSIX
 * (supra) backend. The target object carries a singly-linked list of the
 * addresses of the weakref slots pointing at it; on finalize each slot is set
 * to NULL. Assigning a weakref (un)registers the slot on the old/new target,
 * and a weakref local/field is unregistered when it leaves scope / the holder
 * dies. Split out of CCodeSupraModule; sits above it in the supra chain.
 */

using Vala;

public class Vala.CCodeSupraWeakRefModule : CCodeSupraSignalModule {

	private const string WEAKREF_FIELD = "__weak_refs";

	// The class that owns the weakref registration list for a weakref type: the
	// topmost base (offset 0 of every instance, so any object pointer reaches
	// it). Null for non-class / non-supraklass types (weakref inert then).
	private unowned Class? weakref_root_class (DataType? type) {
		if (type == null || !type.is_weak_ref) {
			return null;
		}
		unowned Class? cl = type.type_symbol as Class;
		if (cl == null || !cl.is_supraklass) {
			return null;
		}
		return get_root_class (cl);
	}

	// The root class holds the single per-object registration list.
	private bool is_weakref_root (Class cl) {
		return cl.base_class == null && cl.is_supraklass;
	}

	private void emit_weakref_typedef (CCodeFile decl_space) {
		// With a generated header every source includes it, so the typedef must
		// live there once; otherwise each TU is standalone and emits its own.
		unowned CCodeFile target = (context.header_filename != null) ? header_file : decl_space;
		if (target.add_declaration ("supra_weakref")) {
			return;
		}
		target.add_include ("stddef.h");
		target.add_type_declaration (new CCodeIdentifier (
			"""typedef struct _supra_weakref {
	void** slot;
	struct _supra_weakref* next;
} supra_weakref;"""));
	}

	// Emit the named runtime helper into cfile once (idempotent via add_wrapper).
	private void ensure_weakref_fn (string name) {
		if (!add_wrapper (name)) {
			return;
		}
		emit_weakref_typedef (cfile);
		cfile.add_include ("stdlib.h");
		string body;
		switch (name) {
		case "supra_weakref_register":
			body = """static void supra_weakref_register (supra_weakref** head, void** slot) {
	supra_weakref* c = (supra_weakref*) malloc (sizeof (supra_weakref));
	c->slot = slot;
	c->next = *head;
	*head = c;
}""";
			break;
		case "supra_weakref_unregister":
			body = """static void supra_weakref_unregister (supra_weakref** head, void** slot) {
	while (*head != NULL) {
		if ((*head)->slot == slot) {
			supra_weakref* dead = *head;
			*head = dead->next;
			free (dead);
			return;
		}
		head = &(*head)->next;
	}
}""";
			break;
		case "supra_weakref_clear":
			body = """static void supra_weakref_clear (supra_weakref** head) {
	while (*head != NULL) {
		supra_weakref* dead = *head;
		*head = dead->next;
		*dead->slot = NULL;
		free (dead);
	}
}""";
			break;
		default:
			assert_not_reached ();
		}
		cfile.add_type_member_definition (new CCodeIdentifier (body));
	}

	protected override void append_supra_weakref_field (Class cl, CCodeStruct instance_struct, CCodeFile decl_space) {
		if (!is_weakref_root (cl)) {
			return;
		}
		emit_weakref_typedef (decl_space);
		instance_struct.add_field ("supra_weakref*", WEAKREF_FIELD);
	}

	protected override void emit_supra_weakref_init (Class cl) {
		if (!is_weakref_root (cl)) {
			return;
		}
		var field = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), WEAKREF_FIELD);
		ccode.add_assignment (field, new CCodeConstant ("NULL"));
	}

	protected override void emit_supra_weakref_finalize (Class cl) {
		// (a) unregister this class's own weakref instance fields (holder dying)
		var this_type = SemanticAnalyzer.get_data_type_for_symbol (cl);
		var instance = new GLibValue (this_type, new CCodeIdentifier ("self"), true);
		foreach (Field f in cl.get_fields ()) {
			if (f.binding != MemberBinding.INSTANCE) {
				continue;
			}
			unowned Class? root = weakref_root_class (f.variable_type);
			if (root == null) {
				continue;
			}
			emit_weakref_op ("supra_weakref_unregister", get_cvalue_ (get_field_cvalue (f, instance)), root);
		}

		// (b) root only: null every slot still pointing at this dying object
		if (!is_weakref_root (cl)) {
			return;
		}
		ensure_weakref_fn ("supra_weakref_clear");
		var head = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
			new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), WEAKREF_FIELD));
		var call = new CCodeFunctionCall (new CCodeIdentifier ("supra_weakref_clear"));
		call.add_argument (head);
		ccode.add_expression (call);
	}

	public override void store_local (LocalVariable local, TargetValue value, bool initializer, SourceReference? source_reference = null) {
		unowned Class? root = weakref_root_class (local.variable_type);
		if (context.profile == Profile.POSIX && root != null) {
			emit_weakref_store (get_cvalue_ (get_local_cvalue (local)), get_cvalue_ (value), initializer, root);
			return;
		}
		base.store_local (local, value, initializer, source_reference);
	}

	public override void store_field (Field field, TargetValue? instance, TargetValue value, bool initializer, SourceReference? source_reference = null) {
		unowned Class? root = weakref_root_class (field.variable_type);
		if (context.profile == Profile.POSIX && root != null) {
			emit_weakref_store (get_cvalue_ (get_field_cvalue (field, instance)), get_cvalue_ (value), initializer, root);
			return;
		}
		base.store_field (field, instance, value, initializer, source_reference);
	}

	// Assign a weakref slot: unregister the old target (unless first init),
	// store the new value, register the slot on the new (non-null) target.
	private void emit_weakref_store (CCodeExpression lvalue, CCodeExpression rvalue, bool initializer, Class root) {
		if (!initializer) {
			emit_weakref_op ("supra_weakref_unregister", lvalue, root);
		}
		ccode.add_assignment (lvalue, rvalue);
		if (!is_null_constant (rvalue)) {
			emit_weakref_op ("supra_weakref_register", lvalue, root);
		}
	}

	private bool is_null_constant (CCodeExpression expr) {
		unowned CCodeConstant? c = expr as CCodeConstant;
		return c != null && c.name == "NULL";
	}

	protected override void append_scope_free (Symbol sym, CodeNode? stop_at = null) {
		unowned Block? b = sym as Block;
		if (context.profile == Profile.POSIX && b != null) {
			var local_vars = b.get_local_variables ();
			for (int i = local_vars.size - 1; i >= 0; i--) {
				var local = local_vars[i];
				unowned Class? root = weakref_root_class (local.variable_type);
				if (root == null || local.unreachable || !local.active || local.captured) {
					continue;
				}
				emit_weakref_op ("supra_weakref_unregister", get_cvalue_ (get_local_cvalue (local)), root);
			}
		}
		base.append_scope_free (sym, stop_at);
	}

	// Emit `if (slot != NULL) fn (&((Root*)slot)->__weak_refs, (void**) &slot);`,
	// ensuring the named runtime helper is defined. `slot` is the weakref lvalue,
	// which holds the target pointer (so it is both the list owner and the slot).
	private void emit_weakref_op (string fn, CCodeExpression slot, Class root) {
		ensure_weakref_fn (fn);
		var head = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF,
			new CCodeMemberAccess.pointer (
				new CCodeCastExpression (slot, "%s*".printf (get_ccode_name (root))),
				WEAKREF_FIELD));
		var slot_addr = new CCodeCastExpression (
			new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, slot), "void**");
		var call = new CCodeFunctionCall (new CCodeIdentifier (fn));
		call.add_argument (head);
		call.add_argument (slot_addr);

		var notnull = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, slot, new CCodeConstant ("NULL"));
		ccode.open_if (notnull);
		ccode.add_expression (call);
		ccode.close ();
	}
}
