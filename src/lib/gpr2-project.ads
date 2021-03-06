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

with Ada.Containers;

with GNATCOLL.Refcount;
with GNATCOLL.Tribooleans;

with GPR2.Containers;
with GPR2.Context;
with GPR2.Path_Name.Set;

private with GPR2.Source_Reference.Value;

package GPR2.Project is

   use GNATCOLL.Tribooleans;

   use type Ada.Containers.Count_Type;

   --  This package is the root of the high level abstraction of a hierarchy of
   --  projects given by a root project.

   type Standalone_Library_Kind is (No, Standard, Encapsulated, Full);

   --
   --  Iterators
   --

   type Iterator_Kind is
     (I_Project, I_Extended, I_Imported, I_Aggregated, I_Recursive);
   type Iterator_Control is array (Iterator_Kind) of Boolean  with Pack;

   Default_Iterator : constant Iterator_Control;

   Config_File_Extension  : constant Filename_Type := ".cgpr";
   Project_File_Extension : constant Filename_Type := ".gpr";
   --  The standard config and user project file name extensions

   Config_File_Extension_No_Dot : Filename_Type
     renames Config_File_Extension (2 .. Config_File_Extension'Last);

   Project_File_Extension_No_Dot : Filename_Type
     renames Project_File_Extension (2 .. Project_File_Extension'Last);

   Default_Config_Name : constant Filename_Type := "default.cgpr";

   Implicit_Project : Path_Name.Object renames Path_Name.Implicit_Project;
   --  Means that an empty project has to be generated instead of parsed from
   --  file.

   type Filter_Kind is
     (F_Standard, F_Library, F_Abstract, F_Aggregate, F_Aggregate_Library);
   type Filter_Control is array (Filter_Kind) of Boolean with Pack;

   Default_Filter : constant Filter_Control;
   Library_Filter : constant Filter_Control;

   type Status_Kind is
     (S_Externally_Built);
   type Status_Control is array (Status_Kind) of Triboolean;

   Default_Status : constant Status_Control;

   function Create
     (Name  : Filename_Type;
      Paths : Path_Name.Set.Object := Path_Name.Set.Empty_Set)
      return Path_Name.Object;
   --  Given a filename (possibly a full pathname) returns a Path_Name_Type. If
   --  Name is not an absolute path name it is looked into Paths.

   function Search_Paths
     (Root_Project      : Path_Name.Object;
      Tree_Search_Paths : Path_Name.Set.Object) return Path_Name.Set.Object
     with Pre  => Root_Project.Is_Defined
                  and then not Tree_Search_Paths.Is_Empty,
          Post => not Search_Paths'Result.Is_Empty;
   --  Returns the project search path for the given project and the given tree

   function Ensure_Extension (Name : Filename_Type) return Filename_Type;
   --  If Name ending with ".gpr" or ".cgpr" the function returns it unchanged,
   --  otherwise returns Name appended with ".gpr" suffix.

   function Default_Search_Paths
     (Current_Directory : Boolean) return Path_Name.Set.Object
   with Post => Default_Search_Paths'Result.Length > 0;
   --  Get the search paths common for all targets.
   --  If Current_Directory is True then the current directory is incuded at
   --  the first place in the result set.

   procedure Append_Default_Search_Paths (Paths : in out Path_Name.Set.Object);
   --  Add Default_Search_Paths without current directory to the Paths
   --  parameter.

private

   type Relation_Status is (Root, Imported, Extended, Aggregated);

   type Definition_Base is abstract tagged record
      Id                : Natural := 0;
      Path              : Path_Name.Object;
      Externals         : Containers.Name_List;
      --  List of externals directly or indirectly visible
      Signature         : Context.Binary_Signature :=
                            Context.Default_Signature;
      Status            : Relation_Status := Root;
      Kind              : Project_Kind;
      Sources_Signature : Context.Binary_Signature :=
                            Context.Default_Signature;
   end record;

   package Definition_References is new GNATCOLL.Refcount.Shared_Pointers
     (Definition_Base'Class);

   subtype Weak_Reference is Definition_References.Weak_Ref;

   Default_Iterator : constant Iterator_Control := (others => True);

   Default_Filter   : constant Filter_Control := (others => True);

   Library_Filter   : constant Filter_Control :=
                        (F_Library | F_Aggregate_Library => True,
                         others                          => False);

   Default_Status : constant Status_Control := (others => Indeterminate);

   function At_Pos_Or
     (Value   : Source_Reference.Value.Object'Class;
      Default : Natural) return Natural
   is
     (if Value.Is_Defined and then Value.Has_At_Pos
      then Value.At_Pos
      else Default);
   --  Returns At_Pos if defined or Default if not defined

end GPR2.Project;
