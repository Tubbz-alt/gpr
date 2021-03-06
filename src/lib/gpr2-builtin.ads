------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                    Copyright (C) 2019-2020, AdaCore                      --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

--  This package contains the implementation of all GPR built-ins like
--  External, External_As_List, Split. The built-in specs are following closely
--  the actual grammar so basically they take a set of string parameters and
--  should return a single string or a list of string.

with GPR2.Containers;
with GPR2.Context;
with GPR2.Source_Reference.Value;

package GPR2.Builtin is

   No_Value : constant Value_Type;
   --  No value specified, different than the empty string

   function External
     (Context       : GPR2.Context.Object;
      Variable      : Name_Type;
      Default_Value : Source_Reference.Value.Object :=
                        Source_Reference.Value.Undefined;
      Sloc          : Source_Reference.Object :=
                        Source_Reference.Undefined)
      return Source_Reference.Value.Object
     with Post =>
       (if Context.Contains (Variable)
        then External'Result.Text = Context (Variable));
   --  The External built-in. Returns the value for Variable either in the
   --  context if found or the default value otherwise. If no default value
   --  is specified, the exception is raised.

   function External_As_List
     (Context   : GPR2.Context.Object;
      Variable  : Name_Type;
      Separator : Name_Type) return Containers.Value_List;
   --  The External_As_List built-in. Returns a list of values corresponding
   --  to the data found in context's Variable split using the given separator.

   function Split
     (Value     : Name_Type;
      Separator : Name_Type) return Containers.Value_List
     renames Containers.Create;
   --  The Split built-in. Returns a list of values corresponding
   --  to the string value split using the given separator.

private

   No_Value : constant Value_Type := Value_Type'(1 => ASCII.NUL);

end GPR2.Builtin;
