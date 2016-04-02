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

with GPR2.Containers;

package body GPR2.Project.Pack is

   ----------------
   -- Attributes --
   ----------------

   function Attributes
     (Self  : Object;
      Name  : String := "";
      Index : String := "") return Attribute.Set.Object is
   begin
      return Self.Attrs.Filter (Name, Index);
   end Attributes;

   ------------
   -- Create --
   ------------

   function Create
     (Name       : Name_Type;
      Attributes : Attribute.Set.Object;
      Sloc       : Source_Reference.Object) return Object is
   begin
      return Object'(Sloc with To_Unbounded_String (Name), Attributes);
   end Create;

   --------------------
   -- Has_Attributes --
   --------------------

   function Has_Attributes
     (Self  : Object;
      Name  : String := "";
      Index : String := "") return Boolean is
      use type Containers.Count_Type;
   begin
      if Name = "" and then Index = "" then
         return not Self.Attrs.Is_Empty;

      elsif Index = "" then
         return Self.Attrs.Contains (Name);

      else
         return not Attributes (Self, Name, Index).Is_Empty;
      end if;
   end Has_Attributes;

   ----------
   -- Name --
   ----------

   function Name (Self : Object) return Name_Type is
   begin
      return To_String (Self.Name);
   end Name;

end GPR2.Project.Pack;
