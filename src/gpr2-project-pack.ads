------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--            Copyright (C) 2016, Free Software Foundation, Inc.            --
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

--  Handle project's packages which are a set of attributes

with GPR2.Project.Attribute.Set;

private with Ada.Strings.Unbounded;

package GPR2.Project.Pack is

   type Object is tagged private;

   Undefined : constant Object;

   function Create
     (Name       : Name_Type;
      Attributes : Attribute.Set.Object) return Object;
   --  Create a package object with the given Name and the list of attributes.
   --  Note that the list of attribute can be empty as a package can contain no
   --  declaration.

   function Name (Self : Object) return Name_Type
     with Pre => Self /= Undefined;
   --  Returns the name of the project

   function Has_Attributes (Self : Object) return Boolean
     with Pre => Self /= Undefined;
   --  Returns true if the package has some attributes defined

   function Attributes (Self : Object) return Attribute.Set.Object
     with Pre => Self /= Undefined;
   --  Returns all attributes defined for the package

private

   use Ada.Strings.Unbounded;

   type Object is tagged record
      Name  : Unbounded_String;
      Attrs : Attribute.Set.Object;
   end record;

   Undefined : constant Object := Object'(Null_Unbounded_String, Attrs => <>);

end GPR2.Project.Pack;