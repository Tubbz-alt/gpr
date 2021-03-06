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

with GPR2.KB;
with GPR2.Message;
with GPR2.Project.Attribute;
with GPR2.Project.Attribute_Index;
with GPR2.Project.Definition;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Registry.Pack;
with GPR2.Source_Reference.Value;

pragma Warnings (Off);
with System.OS_Constants;
pragma Warnings (On);

package body GPR2.Project.Configuration is

   package PRA renames Project.Registry.Attribute;
   package PRP renames Project.Registry.Pack;

   --------------------
   -- Archive_Suffix --
   --------------------

   function Archive_Suffix (Self : Object) return Filename_Type is
   begin
      return Filename_Type
               (Self.Conf.Attribute (PRA.Archive_Suffix).Value.Text);
   end Archive_Suffix;

   ------------------
   -- Bind_To_Tree --
   ------------------

   procedure Bind_To_Tree
     (Self : in out Object;
      Tree : not null access Project.Tree.Object)
   is
      Data : Definition.Data;
   begin
      Data.Trees.Project := Self.Project;
      Data.Status        := Root;
      Data.Kind          := K_Configuration;
      Data.Tree          := Tree;
      Data.Path          := Path_Name.Create_Directory
                              (Filename_Type
                                 (Self.Project.Path_Name.Dir_Name));
      Self.Conf          := Definition.Register (Data);
   end Bind_To_Tree;

   ------------------------
   -- Corresponding_View --
   ------------------------

   function Corresponding_View (Self : Object) return Project.View.Object is
   begin
      return Self.Conf;
   end Corresponding_View;

   ------------
   -- Create --
   ------------

   function Create
     (Language : Name_Type;
      Version  : Optional_Name_Type := No_Name;
      Runtime  : Optional_Name_Type := No_Name;
      Path     : Optional_Name_Type := No_Name;
      Name     : Optional_Name_Type := No_Name) return Description
   is
      function "+" (Str : Optional_Name_Type) return Unbounded_String
        is (To_Unbounded_String (String (Str)));
   begin
      return Description'
        (Language => +Language,
         Version  => +Version,
         Runtime  => +Runtime,
         Path     => +Path,
         Name     => +Name);
   end Create;

   function Create
     (Settings   : Description_Set;
      Target     : Name_Type;
      Project    : GPR2.Path_Name.Object;
      Base       : in out GPR2.KB.Object)
      return Object
   is

      Native_Target : constant Boolean := Target = "all";

      Result    : Object;
      Host      : constant Name_Type :=
                    Name_Type (System.OS_Constants.Target_Name);

      Configuration_String : Unbounded_String;
      Parsing_Messages     : Log.Object;

   begin

      if Native_Target then
         --  Normalize implicit target
         declare
            Normalized : constant Name_Type := Base.Normalized_Target (Host);
         begin
            if Normalized = "unknown" then
               Configuration_String :=
                 Base.Configuration
                   (Settings => Settings,
                    Target   => Name_Type (System.OS_Constants.Target_Name),
                    Messages => Result.Messages,
                    Fallback => True);
            else
               Configuration_String :=
                 Base.Configuration
                   (Settings => Settings,
                    Target   => Normalized,
                    Messages => Result.Messages,
                    Fallback => True);
            end if;
         end;

      else
         Configuration_String :=
           Base.Configuration
             (Settings => Settings,
              Target   => Target,
              Messages => Result.Messages,
              Fallback => False);
      end if;

      if Configuration_String /= Null_Unbounded_String then

         if Path_Name.Temporary_Directory.Is_Defined then
            Result.Project :=
              Parser.Project.Parse
                (Contents        => Configuration_String,
                 Messages        => Parsing_Messages,
                 Pseudo_Filename => Path_Name.Create_File
                   ("autoconf.cgpr",
                    Filename_Type (Path_Name.Temporary_Directory.Value)));
         else
            Result.Project :=
              Parser.Project.Parse
                (Contents        => Configuration_String,
                 Messages        => Parsing_Messages,
                 Pseudo_Filename => Path_Name.Create_File
                   ("autoconf.cgpr",
                    Filename_Type (Project.Dir_Name)));
         end if;

         --  Continue only if there is no parsing error on the configuration
         --  project.

         if Result.Project.Is_Defined then
            Result.Target :=
              (if Target = "all"
               then Null_Unbounded_String
               else To_Unbounded_String (String (Target)));
         end if;

         for S of Settings loop
            Result.Descriptions.Append (S);
         end loop;

      else

         Result.Messages.Append
           (Message.Create
              (Message.Error,
               "cannot create configuration file, fail to execute gprconfig",
               Sloc => Source_Reference.Create (Project.Value, 0, 0)));
      end if;

      return Result;
   end Create;

   ----------------------------
   -- Dependency_File_Suffix --
   ----------------------------

   function Dependency_File_Suffix
     (Self     : Object;
      Language : Name_Type) return Filename_Type
   is
      pragma Unreferenced (Self);
   begin
      --  ??? there is no attribute in the configuration file for this, so we
      --  end up having hard coded value for Ada and all other languages.
      if Language = "Ada" then
         return ".ali";
      else
         return ".d";
      end if;
   end Dependency_File_Suffix;

   ---------------
   -- Externals --
   ---------------

   function Externals (Self : Object) return Containers.Name_List is
   begin
      return Self.Project.Externals;
   end Externals;

   -------------------
   -- Has_Externals --
   -------------------

   function Has_Externals (Self : Object) return Boolean is
   begin
      return Self.Project.Is_Defined and then Self.Project.Has_Externals;
   end Has_Externals;

   ------------------
   -- Has_Messages --
   ------------------

   function Has_Messages (Self : Object) return Boolean is
   begin
      return not Self.Messages.Is_Empty;
   end Has_Messages;

   ----------
   -- Load --
   ----------

   function Load
     (Filename : Path_Name.Object;
      Target   : Name_Type := "all") return Object
   is
      Result : Object;
   begin
      Result.Project :=
        Parser.Project.Parse
          (Filename, Containers.Empty_Filename_Set, Result.Messages);

      --  Continue only if there is no parsing error on the configuration
      --  project.

      if Result.Project.Is_Defined then
         Result.Target :=
           (if Target = "all"
            then Null_Unbounded_String
            else To_Unbounded_String (String (Target)));
      end if;

      return Result;
   end Load;

   ------------------
   -- Log_Messages --
   ------------------

   function Log_Messages (Self : Object) return Log.Object is
   begin
      return Self.Messages;
   end Log_Messages;

   ------------------------
   -- Object_File_Suffix --
   ------------------------

   function Object_File_Suffix
     (Self     : Object;
      Language : Name_Type) return Filename_Type
   is
      A : Project.Attribute.Object;
   begin
      if Self.Conf.Has_Packages (PRP.Compiler)
        and then Self.Conf.Pack (PRP.Compiler).Check_Attribute
                   (PRA.Object_File_Suffix,
                    Attribute_Index.Create (Value_Type (Language)),
                    Result => A)
      then
         return Filename_Type (A.Value.Text);
      else
         return ".o";
      end if;
   end Object_File_Suffix;

   -------------
   -- Runtime --
   -------------

   function Runtime
     (Self : Object; Language : Name_Type) return Optional_Name_Type is
   begin
      for Description of Self.Descriptions loop
         if Optional_Name_Type (To_String (Description.Language))
           = Language
         then
            return Optional_Name_Type (To_String (Description.Runtime));
         end if;
      end loop;

      return "";
   end Runtime;

   ------------
   -- Target --
   ------------

   function Target (Self : Object) return Optional_Name_Type is
   begin
      return Optional_Name_Type (To_String (Self.Target));
   end Target;

begin
   Definition.Bind_Configuration_To_Tree := Bind_To_Tree'Access;
end GPR2.Project.Configuration;
