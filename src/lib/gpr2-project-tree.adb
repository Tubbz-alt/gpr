------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--         Copyright (C) 2016-2017, Free Software Foundation, Inc.          --
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

with Ada.Containers.Ordered_Sets; use Ada;
with Ada.Environment_Variables;

with GPR2.Parser.Project;
with GPR2.Project.Attribute.Set;
with GPR2.Project.Name_Values;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Registry.Pack;
with GPR2.Source_Reference;

package body GPR2.Project.Tree is

   type Iterator (Kind : Iterator_Kind; Filter : Project_Filter) is
     new Project_Iterator.Forward_Iterator with
   record
     Root : not null access constant Object;
   end record;

   overriding function First
     (Iter : Iterator) return Cursor;

   overriding function Next
     (Iter : Iterator; Position : Cursor) return Cursor;

   function Recursive_Load
     (Filename     : Path_Name_Type;
      Context_View : View.Object;
      Status       : Definition.Relation_Status;
      Root_Context : out GPR2.Context.Object;
      Messages     : out Log.Object) return View.Object;
   --  Load a project filename recurivelly and returns the corresponding root
   --  view.

   --------------------
   -- Append_Message --
   --------------------

   procedure Append_Message
     (Self    : in out Object;
      Message : GPR2.Message.Object) is
   begin
      Self.Messages.Append (Message);
   end Append_Message;

   ---------------------------
   -- Configuration_Project --
   ---------------------------

   function Configuration_Project (Self : Object) return View.Object is
   begin
      return Self.Conf;
   end Configuration_Project;

   ------------------------
   -- Constant_Reference --
   ------------------------

   function Constant_Reference
     (Self     : aliased Object;
      Position : Cursor) return Constant_Reference_Type
   is
      pragma Unreferenced (Self);
   begin
      --  Constant reference is given by the constant reference of the
      --  element contained in the Views set at the current location.
      return Constant_Reference_Type'
        (View =>
           Definition.Project_View_Store.Constant_Reference
             (Position.Views, Position.Current).Element);
   end Constant_Reference;

   -------------
   -- Context --
   -------------

   function Context (Self : Object) return GPR2.Context.Object is
   begin
      return Self.Root_Project.Context;
   end Context;

   -------------
   -- Element --
   -------------

   function Element (Position : Cursor) return View.Object is
   begin
      return Position.Views (Position.Current);
   end Element;

   -----------
   -- First --
   -----------

   overriding function First (Iter : Iterator) return Cursor is

      use type View.Id;

      package Seen_Project is new Containers.Ordered_Sets (View.Object);

      Seen : Seen_Project.Set;
      --  Keep track of already seen projects. Better than using the P vector
      --  which is not efficient when checking if an element exists.

      Projects : Definition.Project_View_Store.Vector;
      --  Set of projects for the iterator which is returned in the Cursor and
      --  fill by the recursive procedure For_Project and For_Imports.

      procedure Append (View : Project.View.Object)
        with Post => Seen.Contains (View);
      --  Append into P if not already seen

      procedure For_Project (View : Project.View.Object);
      --  Handle project node

      procedure For_Imports (View : Project.View.Object);
      --  Handle import nodes

      procedure For_Aggregated (View : Project.View.Object);
      --  Handle aggregated nodes

      ------------
      -- Append --
      ------------

      procedure Append (View : Project.View.Object) is
         Qualifier : constant Project_Kind := View.Kind;
      begin
         if not Seen.Contains (View) then
            --  Check if it corresponds to the current filter
            if (Qualifier = K_Library
                and then Is_Set (Iter.Filter, F_Library))
              or else (Qualifier = K_Standard
                       and then Is_Set (Iter.Filter, F_Standard))
              or else (Qualifier = K_Abstract
                       and then Is_Set (Iter.Filter, F_Abstract))
              or else (Qualifier = K_Aggregate
                       and then Is_Set (Iter.Filter, F_Aggregate))
              or else (Qualifier = K_Aggregate_Library
                       and then Is_Set (Iter.Filter, F_Aggregate_Library))
            then
               Projects.Append (View);
            end if;

            Seen.Insert (View);
         end if;
      end Append;

      --------------------
      -- For_Aggregated --
      --------------------

      procedure For_Aggregated (View : Project.View.Object) is
      begin
         if View.Kind in K_Aggregate | K_Aggregate_Library then
            for A of Definition.Get (View).Aggregated loop
               Append (A);
            end loop;
         end if;
      end For_Aggregated;

      -----------------
      -- For_Imports --
      -----------------

      procedure For_Imports (View : Project.View.Object) is
      begin
         for I of Definition.Get (View).Imports loop
            if Is_Set (Iter.Kind, I_Recursive) then
               For_Project (I);
            else
               Append (I);
            end if;
         end loop;
      end For_Imports;

      -----------------
      -- For_Project --
      -----------------

      procedure For_Project (View : Project.View.Object) is
      begin
         --  Handle imports

         if Is_Set (Iter.Kind, I_Imported)
           or else Is_Set (Iter.Kind, I_Recursive)
         then
            For_Imports (View);
         end if;

         --  Handle extended if any

         if Is_Set (Iter.Kind, I_Extended) then
            declare
               Data : constant Definition.Data := Definition.Get (View);
            begin
               if Data.Extended /= Project.View.Undefined then
                  Append (Data.Extended);
               end if;
            end;
         end if;

         --  The project itself

         Append (View);

         --  Now if View is an aggregate or aggregate library project we need
         --  to run through all aggregated projects.

         if Is_Set (Iter.Kind, I_Aggregated) then
            For_Aggregated (View);
         end if;
      end For_Project;

   begin
      For_Project (Iter.Root.Root);
      return Cursor'(Projects, 1, Iter.Root.Root);
   end First;

   -------------------------------
   -- Has_Configuration_Project --
   -------------------------------

   function Has_Configuration_Project (Self : Object) return Boolean is
   begin
      return Self.Conf /= View.Undefined;
   end Has_Configuration_Project;

   -----------------
   -- Has_Context --
   -----------------

   function Has_Context (Self : Object) return Boolean is
   begin
      return not Self.Root_Project.Context.Is_Empty;
   end Has_Context;

   -----------------
   -- Has_Element --
   -----------------

   function Has_Element (Position : Cursor) return Boolean is
   begin
      return Position /= No_Element;
   end Has_Element;

   ------------------
   -- Has_Messages --
   ------------------

   function Has_Messages (Self : Object) return Boolean is
   begin
      return not Self.Messages.Is_Empty;
   end Has_Messages;

   -------------
   -- Is_Root --
   -------------

   function Is_Root (Position : Cursor) return Boolean is
   begin
      return Position.Views (Position.Current) = Position.Root;
   end Is_Root;

   -------------
   -- Iterate --
   -------------

   function Iterate
     (Self   : Object;
      Kind   : Iterator_Kind := I_Default;
      Filter : Project_Filter := F_Default)
      return Project_Iterator.Forward_Iterator'Class is
   begin
      return Iterator'(Kind, Filter, Self.Self);
   end Iterate;

   ----------
   -- Load --
   ----------

   procedure Load
     (Self     : in out Object;
      Filename : Path_Name_Type;
      Context  : GPR2.Context.Object)
   is
      Root_Context : GPR2.Context.Object := Context;

   begin
      Self.Root := Recursive_Load
        (Filename, View.Undefined, Definition.Root,
         Root_Context, Self.Messages);

      --  Do nothing more if there are errors during the parsing

      if Self.Messages.Is_Empty then
         for View of Self loop
            declare
               V_Data : Definition.Data := Definition.Get (View);
            begin
               --  Compute the external dependencies for the views. This
               --  is the set of external used in the project and in all
               --  imported project.

               for E of V_Data.Externals loop
                  if not V_Data.Externals.Contains (E) then
                     V_Data.Externals.Append (E);
                  end if;
               end loop;

               Definition.Set (View, V_Data);
            end;
         end loop;

         Set_Context (Self, Root_Context);

         if not Self.Messages.Is_Empty then
            raise Project_Error with "semantic error";
         end if;

      else
         raise Project_Error with "syntax error";
      end if;
   end Load;

   ------------------------
   -- Load_Configuration --
   ------------------------

   procedure Load_Configuration
     (Self     : in out Object;
      Filename : Path_Name_Type)
   is
      Project : constant Parser.Project.Object :=
                  Parser.Project.Load (Filename, Self.Messages);
      Data    : Definition.Data (Has_Context => False);
   begin
      --  Continue only if there is no parsing error on the configuration
      --  project.

      if Self.Messages.Is_Empty then
         Data.Trees.Project := Project;
         Data.Context_View := View.Undefined;
         Data.Status := Definition.Root;

         Self.Conf := Definition.Register (Data);

         --  Finaly reload/reset the context

         Set_Context (Self, Self.Context);
      end if;
   end Load_Configuration;

   ------------------
   -- Log_Messages --
   ------------------

   function Log_Messages (Self : Object) return not null access Log.Object is
   begin
      return Self.Self.Messages'Access;
   end Log_Messages;

   ----------
   -- Next --
   ----------

   overriding function Next
     (Iter : Iterator; Position : Cursor) return Cursor
   is
      pragma Unreferenced (Iter);
      C : Cursor := Position;
   begin
      if C.Current < Natural (C.Views.Length) then
         C.Current := C.Current + 1;
         return C;
      else
         return No_Element;
      end if;
   end Next;

   --------------------
   -- Recursive_Load --
   --------------------

   function Recursive_Load
     (Filename     : Path_Name_Type;
      Context_View : View.Object;
      Status       : Definition.Relation_Status;
      Root_Context : out GPR2.Context.Object;
      Messages     : out Log.Object) return View.Object

   is
      function Load (Filename : Path_Name_Type) return Definition.Data;
      --  Returns the Data definition for the given project

      function Is_In_Closure
        (Project_Name : Path_Name_Type;
         Data         : Definition.Data;
         Messages     : out Log.Object) return Boolean;
      --  Returns True if Project_Name is in the closure of the project whose
      --  Data definition is given.

      -------------------
      -- Is_In_Closure --
      -------------------

      function Is_In_Closure
        (Project_Name : Path_Name_Type;
         Data         : Definition.Data;
         Messages     : out Log.Object) return Boolean
      is

         function Is_In_Closure (Data : Definition.Data) return Boolean;
         --  True if Project_Name is in closure of Data

         function Is_In_Imports (Data : Definition.Data) return Boolean;
         --  True if Project_Name is in imports of Data

         -------------------
         -- Is_In_Closure --
         -------------------

         function Is_In_Closure (Data : Definition.Data) return Boolean is
         begin
            return Data.Trees.Imports.Contains (Project_Name)
              or else Is_In_Imports (Data);
         end Is_In_Closure;

         -------------------
         -- Is_In_Imports --
         -------------------

         function Is_In_Imports (Data : Definition.Data) return Boolean is
         begin
            for Import of Data.Trees.Imports loop
               --  Skip limited imports
               if not Data.Trees.Project.Imports.Element
                 (Import.Path_Name).Is_Limited
               then
                  if Is_In_Closure (Load (Import.Path_Name)) then
                     Messages.Append
                       (Message.Create
                          (Message.Error,
                           "imports " & Value (Import.Path_Name),
                           Source_Reference.Object
                             (Data.Trees.Project.Imports.Element
                                  (Import.Path_Name))));
                     return True;
                  end if;
               end if;
            end loop;

            return False;
         end Is_In_Imports;

      begin
         return Is_In_Imports (Data);
      end Is_In_Closure;

      ----------

      -- Load --
      ----------

      function Load (Filename : Path_Name_Type) return Definition.Data is
         Project : constant Parser.Project.Object :=
                     Parser.Project.Load (Filename, Messages);

         Data    : Definition.Data
                     (Has_Context =>
                        (Context_View = GPR2.Project.View.Undefined)
                      or else Project.Qualifier = K_Aggregate);
      begin
         Data.Trees.Project := Project;

         --  Do the following only if there are no error messages

         if Messages.Is_Empty then
            Data.Kind := Project.Qualifier;
            Data.Externals := Data.Trees.Project.Externals;

            --  Now load all imported projects if any

            for Import of Data.Trees.Project.Imports loop
               Data.Trees.Imports.Insert
                 (Import.Path_Name,
                  Parser.Project.Load (Import.Path_Name, Messages));
            end loop;
         end if;

         return Data;
      end Load;

      Data : Definition.Data := Load (Filename);
      View : Project.View.Object;

   begin
      --  If there are parsing errors, do not go further

      if Messages.Has_Element (Information => False, Warning => False) then
         return View;
      end if;

      --  Let's setup the full external environment for project

      for E of Data.Externals loop
         --  Fill all known external in the environment variables
         if Environment_Variables.Exists (String (E)) then
            Root_Context.Include (E, Environment_Variables.Value (String (E)));
         end if;
      end loop;

      --  If we have the root project, record the global context

      if Data.Has_Context
        and then Context_View = Project.View.Undefined
      then
         --  This is the root-view, assign the corresponding context
         Data.Context := Root_Context;
      end if;

      --  Create the view, needed to be able to reference it if it is an
      --  aggregate project as it becomes the new View_Context.

      Data.Context_View := Context_View;
      Data.Status       := Status;

      View := Definition.Register (Data);

      --  Load the extended project if any

      if Data.Trees.Project.Has_Extended then
         Data.Extended :=
           Recursive_Load
             (Data.Trees.Project.Extended,
              Context_View =>
                (if Context_View = GPR2.Project.View.Undefined
                 then View
                 else Context_View),
              Status       => Definition.Imported,
              Root_Context => Root_Context,
              Messages     => Messages);
      end if;

      --  Now load all imported projects. If we have parsing the root
      --  project or an aggregate project then the context view become
      --  this project.

      for Project of Data.Trees.Imports loop
         declare
            Closure_Message : Log.Object;
         begin
            if Is_In_Closure (Project.Path_Name, Data, Closure_Message) then
               Messages.Append
                 (Message.Create
                    (Message.Error,
                     "circular dependency detected",
                     Source_Reference.Object
                       (Data.Trees.Project.Imports.Element
                            (Project.Path_Name))));

               --  And then add closure circuitry information

               for M of Closure_Message loop
                  Messages.Append (M);
               end loop;

            elsif not Data.Trees.Project.Imports.Element
                        (Project.Path_Name).Is_Limited
            then
               Data.Imports.Append
                 (Recursive_Load
                    (Project.Path_Name,
                     Context_View =>
                       (if Context_View = GPR2.Project.View.Undefined
                        then View
                        else Context_View),
                     Status       => Definition.Imported,
                     Root_Context => Root_Context,
                     Messages     => Messages));
            end if;
         end;
      end loop;

      --  And record back new data for this view

      Definition.Set (View, Data);

      return View;
   end Recursive_Load;

   ------------------
   -- Root_Project --
   ------------------

   function Root_Project (Self : Object) return View.Object is
   begin
      return Self.Root;
   end Root_Project;

   -----------------
   -- Set_Context --
   -----------------

   procedure Set_Context
     (Self    : in out Object;
      Context : GPR2.Context.Object;
      Changed : access procedure (Project : View.Object) := null)
   is

      procedure Set_View (View : Project.View.Object);
      --  Set the context for the given view

      procedure Validity_Check (View : Project.View.Object);
      --  Do validity check on the given view

      --------------
      -- Set_View --
      --------------

      procedure Set_View (View : Project.View.Object) is
         use type GPR2.Context.Binary_Signature;

         P_Data        : Definition.Data := Definition.Get (View);
         Old_Signature : constant GPR2.Context.Binary_Signature :=
                           P_Data.Signature;
         New_Signature : constant GPR2.Context.Binary_Signature :=
                           Context.Signature (P_Data.Externals);
         Context       : constant GPR2.Context.Object :=
                           View.Context;
      begin
         Parser.Project.Parse
           (P_Data.Trees.Project,
            Self,
            Context,
            P_Data.Attrs,
            P_Data.Vars,
            P_Data.Packs);

         --  Now we can record the aggregated projects based on the possibly
         --  new Project_Files attribute value.

         if View.Qualifier in K_Aggregate | K_Aggregate_Library then
            P_Data.Aggregated.Clear;

            for Project of
              P_Data.Attrs.Element (Registry.Attribute.Project_Files).Values
            loop
               declare
                  Pathname : constant Path_Name_Type :=
                               Create (Name_Type (Project));
                  Ctx      : GPR2.Context.Object;
                  A_View   : constant GPR2.Project.View.Object :=
                               Recursive_Load
                                 (Pathname, View,
                                  Definition.Aggregated, Ctx,
                                  Self.Messages);
               begin
                  --  If there was error messages during the parsing of the
                  --  aggregated project, just return now.

                  if Self.Messages.Has_Element
                    (Information => False,
                     Warning     => False)
                  then
                     return;
                  end if;

                  --  Record aggregated view into the aggregate's view

                  P_Data.Aggregated.Append (A_View);

                  --  And set the aggregated view recursivelly
                  Set_View (A_View);
               end;
            end loop;

            --  And finaly also record the External definition if any into
            --  the aggregate project context.

            for C in P_Data.Attrs.Iterate (Registry.Attribute.External) loop
               declare
                  use all type Project.Registry.Attribute.Value_Kind;

                  External : constant Attribute.Object := P_Data.Attrs (C);
               begin
                  --  Check for the validity of the external attribute here
                  --  as the validity check will come after it is fully
                  --  loaded/resolved.
                  if External.Kind = Single then
                     P_Data.A_Context.Include
                       (Name_Type (External.Index), External.Value);
                  end if;
               end;
            end loop;
         end if;

         P_Data.Signature := New_Signature;

         --  Let's compute the project kind if needed. A project without
         --  an explicit qualifier may actually be a library project if
         --  Library_Name, Library_Kind is declared.

         P_Data.Kind := P_Data.Trees.Project.Qualifier;

         if P_Data.Kind = K_Standard then
            if P_Data.Attrs.Contains (Registry.Attribute.Library_Kind)
              or else P_Data.Attrs.Contains (Registry.Attribute.Library_Name)
            then
               P_Data.Kind := K_Library;
            end if;
         end if;

         --  Record the project tree

         P_Data.Tree := Self.Self;

         Definition.Set (View, P_Data);

         --  Signal project change only if we have different and non default
         --  signature. That is if there is at least some external used
         --  otherwise the project is stable and won't change.

         if Old_Signature /= New_Signature
           and then P_Data.Signature /= GPR2.Context.Default_Signature
           and then Changed /= null
         then
            Changed (View);
         end if;
      end Set_View;

      --------------------
      -- Validity_Check --
      --------------------

      procedure Validity_Check (View : Project.View.Object) is
         use type Registry.Attribute.Index_Kind;
         use type Registry.Attribute.Value_Kind;

         procedure Check_Def
           (Def : Registry.Attribute.Def;
            A   : Attribute.Object);
         --  Check if attribute definition is valid, record errors into the
         --  message log facility.

         ---------------
         -- Check_Def --
         ---------------

         procedure Check_Def
           (Def : Registry.Attribute.Def;
            A   : Attribute.Object) is
         begin
            if Def.Index = Registry.Attribute.No
              and then A.Has_Index
            then
               Self.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "attribute " & String (A.Name) & " cannot have index",
                     Source_Reference.Object (A)));
            end if;

            if Def.Value = Registry.Attribute.Single
              and then A.Kind = Registry.Attribute.List
            then
               Self.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "attribute " & String (A.Name) & " cannot be a list",
                     Source_Reference.Object (A)));
            end if;

            if Def.Value = Registry.Attribute.List
              and then A.Kind = Registry.Attribute.Single
            then
               Self.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "attribute " & String (A.Name) & " must be a list",
                     Source_Reference.Object (A)));
            end if;
         end Check_Def;

         P_Kind : constant Project_Kind := View.Kind;
         P_Data : constant Definition.Data := Definition.Get (View);

      begin
         --  Check packages

         for P of P_Data.Packs loop
            if Registry.Pack.Exists (P.Name) then
               --  Check the package itself

               if not Registry.Pack.Is_Allowed_In (P.Name, P_Kind) then
                  Self.Messages.Append
                    (Message.Create
                       (Message.Error,
                        "package " & String (P.Name) & " cannot be used in "
                        & P_Kind'Img,
                        Source_Reference.Object (P)));
               end if;

               --  Check package's attributes

               for A of P.Attributes loop
                  declare
                     Q_Name : constant Registry.Attribute.Qualified_Name :=
                                Registry.Attribute.Create (A.Name, P.Name);
                     Def    : constant Registry.Attribute.Def :=
                                Registry.Attribute.Get (Q_Name);
                  begin
                     if not Def.Is_Allowed_In (P_Kind) then
                        Self.Messages.Append
                          (Message.Create
                             (Message.Error,
                              "attribute " & String (A.Name)
                              & " cannot be used in package "
                              & String (P.Name),
                              Source_Reference.Object (A)));
                     end if;

                     Check_Def (Def, A);
                  end;
               end loop;
            end if;
         end loop;

         --  Check top level attributes

         for A of P_Data.Attrs loop
            declare
               Q_Name : constant Registry.Attribute.Qualified_Name :=
                          Registry.Attribute.Create (A.Name);
            begin
               if not Registry.Attribute.Get
                 (Q_Name).Is_Allowed_In (P_Kind)
               then
                  Self.Messages.Append
                    (Message.Create
                       (Message.Error,
                        "attribute " & String (A.Name)
                        & " cannot be used in " & P_Kind'Img,
                        Source_Reference.Object (A)));
               end if;

               Check_Def (Registry.Attribute.Get (Q_Name), A);
            end;
         end loop;
      end Validity_Check;

   begin
      --  Register the root context for this project tree

      declare
         Data : Definition.Data := Definition.Get (Self.Root_Project);
      begin
         Data.Context := Context;
         Definition.Set (Self.Root_Project, Data);
      end;

      --  Now the first step is to set the configuration project view if any

      if Self.Conf /= View.Undefined then
         Set_View (Self.Conf);
      end if;

      --  Propagate the change in the project Tree. That is for each project in
      --  the tree we need to update the corresponding view. We do not handle
      --  the aggregated projects here. Those projects are handled specifically
      --  in Set_View. This is needed as parsing the aggregate project may
      --  change the Project_Files attribute and so the actual aggregated
      --  project. So we cannot use the current aggregated project list.

      for View in Self.Iterate
        (Kind => I_Project or I_Extended or I_Imported or I_Recursive)
      loop
         Set_View (Element (View));
      end loop;

      --  We now have an up-to-date tree, do some validity checks

      for View of Self loop
         Validity_Check (View);
      end loop;
   end Set_Context;

   --------------
   -- View_For --
   --------------

   function View_For
     (Self : Object;
      Name : Name_Type;
      Ctx  : GPR2.Context.Object) return View.Object
   is
      use type GPR2.Context.Binary_Signature;
   begin
      --  First check for the view in the current tree

      for View of Self.Self.all loop
         if View.Name = Name then
            declare
               P_Data : constant Definition.Data := Definition.Get (View);
               P_Sig  : constant GPR2.Context.Binary_Signature :=
                          Ctx.Signature (P_Data.Externals);
            begin
               if View.Signature = P_Sig then
                  return View;
               end if;
            end;
         end if;
      end loop;

      --  If not found let's check if it is the configuration project

      if Self.Conf /= View.Undefined and then Self.Conf.Name = Name then
         return Self.Conf;
      else
         return View.Undefined;
      end if;
   end View_For;

end GPR2.Project.Tree;