/* valaccodeinitializerlist.vala
 *
 * Copyright (C) 2006-2007  Jürg Billeter
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
 * 	Jürg Billeter <j@bitron.ch>
 */

using GLib;

/**
 * Represents a struct or array initializer list in the C code.
 */
public class Vala.CCodeInitializerList : CCodeExpression {
	private List<CCodeExpression> initializers = new ArrayList<CCodeExpression> ();
	// parallel to initializers; the C99 designated index (`[i] = `) or -1
	private List<int> designators = new ArrayList<int> ();

	/**
	 * Appends the specified expression to this initializer list.
	 *
	 * @param expr an expression
	 */
	public void append (CCodeExpression expr) {
		initializers.add (expr);
		designators.add (-1);
	}

	/**
	 * Appends the specified expression with a C99 designated index.
	 *
	 * @param index the designated array index (`[index] = `)
	 * @param expr  an expression
	 */
	public void append_designated (int index, CCodeExpression expr) {
		initializers.add (expr);
		designators.add (index);
	}

	public override void write (CCodeWriter writer) {
		writer.write_string ("{");

		bool first = true;
		for (int i = 0; i < initializers.size; i++) {
			CCodeExpression? expr = initializers[i];
			if (!first) {
				writer.write_string (", ");
			} else {
				first = false;
			}

			if (designators[i] >= 0) {
				writer.write_string ("[%d] = ".printf (designators[i]));
			}

			if (expr != null) {
				expr.write (writer);
			}
		}

		writer.write_string ("}");
	}
}
