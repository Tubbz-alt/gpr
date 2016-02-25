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
--
--  This is the root package of the GPR2 project support library. There is two
--  child units:
--
--     Parser
--        This child unit and all the children are for the low-level parsing
--        and support. This layer is based on the LangKit parser.
--
--     Project
--        This child unit and all the childrent are the high-level API to
--         work with projects. This is the end-user API.

private with Ada.Strings.Unbounded;

package GPR2 is

   type Project_Qualifier is
     (Q_Configuration, Q_Abstract,
      Q_Standard, Q_Library, Q_Aggregate, Q_Aggregate_Library);

   --
   --  Name / Value
   --

   subtype Name_Type is String
     with Dynamic_Predicate => Name_Type'Length > 0;

   subtype Value_Type is String;

   function Unquote (Str : Value_Type) return Value_Type with
     Post => Unquote'Result (Unquote'Result'First) not in ''' | '"'
             and then Unquote'Result (Unquote'Result'Last) not in ''' | '"'
             and then (Unquote'Result'Length = Str'Length - 2
                       or else Unquote'Result'Length = Str'Length);

   --
   --  Path name
   --

   type Path_Name_Type is private;
   --  A project path-name, will always be normalized according to the running
   --  target.

   function Create (Name : Name_Type) return Path_Name_Type;

   function Value (File : Path_Name_Type) return Name_Type;

private

   use Ada.Strings.Unbounded;

   type Path_Name_Type is record
      As_Is : Unbounded_String;
      Value : Unbounded_String;
   end record;

end GPR2;