/* valaweakrefmodule.vala
 *
 * Copyright (C) 2026 Da Cunha Nathan
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Da Cunha Nathan <hydraldev@gmail.com>
 */

public class Vala.WeakRefModule : Vala.GObjectModule {

	private CCodeExpression generate_function (Variable variable, string function_name, TargetValue? instance = null) {
		var method = variable.variable_type.get_member (function_name) as Method;
		if (method == null) {
			Report.error (variable.source_reference, "Method `%s' not found in `%s'", function_name, variable.variable_type.to_string ());
			return new CCodeConstant ("NULL");
		}

		string method_name = get_ccode_lower_case_name (method);
		string macro_name = "vala_%s0".printf (method_name);
		string self_cast_type = "%s*".printf (get_ccode_name (method.parent_symbol));

		CCodeExpression location;
		if (instance != null && variable is Field) {
			location = get_cvalue_ (get_field_cvalue ((Field) variable, instance));
		} else {
			location = new CCodeIdentifier (get_variable_cname (variable.name));
		}

		var call = new CCodeFunctionCall (new CCodeIdentifier (macro_name));
		call.add_argument (new CCodeCastExpression (location, self_cast_type));
		call.add_argument (new CCodeCastExpression (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, location), "void**"));

		if (!add_symbol_declaration (cfile, variable, macro_name)) {
			cfile.add_type_member_declaration (new CCodeMacroReplacement (
				macro_name + "(var, var2)",
				"((var == NULL) ? NULL : (%s (var, var2), var))".printf (method_name)
			));
		}
		return call;
	}

	private CCodeExpression generate_weak_ref_register (Variable local, TargetValue? instance = null) {
		return generate_function (local, "add_weak_pointer", instance);
	}

	private CCodeExpression generate_weak_ref_unregister (Variable local, TargetValue? instance = null) {
		return generate_function (local, "remove_weak_pointer", instance);
	}

	public override CCodeExpression destroy_local (LocalVariable local) {
		if (local.variable_type != null && local.variable_type.is_weak_ref) {
			return generate_weak_ref_unregister (local);
		}
		return base.destroy_local (local);
	}

	public override void store_local (LocalVariable local, TargetValue value, bool initializer, SourceReference? source_reference = null) {
		base.store_local (local, value, initializer, source_reference);

		if (local.variable_type.is_weak_ref) {
			var call = generate_weak_ref_register (local);
			ccode.add_expression (call);
		}
	}
}
