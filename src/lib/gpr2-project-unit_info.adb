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

package body GPR2.Project.Unit_Info is

   ------------
   -- Create --
   ------------

   function Create
     (Name      : Name_Type;
      Spec      : Path_Name.Object;
      Main_Body : Path_Name.Object;
      Separates : Path_Name.Set.Object) return Object is
   begin
      return Object'(To_Unbounded_String (String (Name)),
                     Spec,
                     Main_Body,
                     Separates);
   end Create;

   -----------------
   -- Update_Body --
   -----------------

   procedure Update_Body
     (Self : in out Object; Source : Path_Name.Object) is
   begin
      Self.Main_Body := Source;
   end Update_Body;

   ----------------------
   -- Update_Separates --
   ----------------------

   procedure Update_Separates
     (Self : in out Object; Source : Path_Name.Object) is
   begin
      Self.Separates.Append (Source);
   end Update_Separates;

   -----------------
   -- Update_Spec --
   -----------------

   procedure Update_Spec
     (Self : in out Object; Source : Path_Name.Object) is
   begin
      Self.Spec := Source;
   end Update_Spec;

end GPR2.Project.Unit_Info;
