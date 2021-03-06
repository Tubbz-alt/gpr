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

with GPR2.Project.Definition;

package body GPR2.Project.Attribute.Set is

   package RA renames Registry.Attribute;

   type Iterator is new Attribute_Iterator.Forward_Iterator with record
      Name          : Unbounded_String;
      Index         : Attribute_Index.Object;
      At_Pos        : Natural := 0;
      Set           : Object;
      With_Defaults : Boolean := False;
   end record;

   overriding function First
     (Iter : Iterator) return Cursor;

   overriding function Next
     (Iter : Iterator; Position : Cursor) return Cursor;

   function Is_Matching
     (Iter : Iterator'Class; Position : Cursor) return Boolean
     with Pre => Has_Element (Position);
   --  Returns True if the current Position is matching the Iterator

   procedure Set_Defaults
     (Self : in out Object;
      VDD  : Definition.Data;
      Pack : Optional_Name_Type);
   --  Set defaults for the attribute set

   -----------
   -- Clear --
   -----------

   procedure Clear (Self : in out Object) is
   begin
      Self.Attributes.Clear;
      Self.Length := 0;
   end Clear;

   ------------------------
   -- Constant_Reference --
   ------------------------

   function Constant_Reference
     (Self     : aliased Object;
      Position : Cursor) return Constant_Reference_Type
   is
      pragma Unreferenced (Self);
   begin
      return Constant_Reference_Type'
        (Attribute =>
           Set_Attribute.Constant_Reference
             (Position.Set.all, Position.CA).Element);
   end Constant_Reference;

   --------------
   -- Contains --
   --------------

   function Contains
     (Self   : Object;
      Name   : Name_Type;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Natural    := 0) return Boolean
   is
      Position : constant Cursor := Self.Find (Name, Index, At_Pos);
   begin
      return Has_Element (Position);
   end Contains;

   function Contains
     (Self      : Object;
      Attribute : Project.Attribute.Object) return Boolean is
   begin
      return Self.Contains
        (Attribute.Name.Text,
         Attribute.Index,
         At_Pos_Or (Source_Reference.Value.Object (Attribute.Index), 0));
   end Contains;

   -------------
   -- Element --
   -------------

   function Element (Position : Cursor) return Attribute.Object is
   begin
      return Set_Attribute.Element (Position.CA);
   end Element;

   function Element
     (Self   : Object;
      Name   : Name_Type;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Natural                := 0) return Attribute.Object
   is
      Position : constant Cursor :=
                   Self.Find (Name, Index, At_Pos);
   begin
      if Set_Attribute.Has_Element (Position.CA) then
         return Element (Position);
      else
         return Project.Attribute.Undefined;
      end if;
   end Element;

   ------------
   -- Filter --
   ------------

   function Filter
     (Self   : Object;
      Name   : Optional_Name_Type     := No_Name;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Natural                := 0) return Object is
   begin
      if Name = No_Name and then not Index.Is_Defined then
         return Self;
      end if;

      declare
         Result : Object;
      begin
         if Name = No_Name then
            for C in Self.Iterate (Name, Index, At_Pos) loop
               Result.Insert (Element (C));
            end loop;

            return Result;
         end if;

         --  If Name is defined we can use fast search for the attributes

         declare
            C : constant Set.Cursor := Self.Attributes.Find (Name);
         begin
            if not Set.Has_Element (C) then
               --  Result is empty here

               return Result;
            end if;

            declare
               Item : constant Set.Constant_Reference_Type :=
                        Self.Attributes (C);
               CI   : Set_Attribute.Cursor;
            begin
               if not Index.Is_Defined then
                  --  All indexes

                  Result.Attributes.Insert (Name, Item);
                  Result.Length := Item.Length;
                  return Result;
               end if;

               --  Specific index only

               CI := Item.Find (Create (Index, At_Pos));

               if Set_Attribute.Has_Element (CI) then
                  declare
                     E : constant Set_Attribute.Constant_Reference_Type :=
                           Item (CI);
                  begin
                     Result.Insert (E);
                     return Result;
                  end;
               end if;

               CI := Item.Find (Create (Attribute_Index.Any, At_Pos));

               if Set_Attribute.Has_Element (CI) then
                  Result.Insert (Item (CI));
                  return Result;
               end if;
            end;
         end;

         return Result;
      end;
   end Filter;

   ----------
   -- Find --
   ----------

   function Find
     (Self   : Object;
      Name   : Name_Type;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Natural                := 0) return Cursor
   is
      Result : Cursor :=
                 (CM  => Self.Attributes.Find (Name),
                  CA  => Set_Attribute.No_Element,
                  Set => null);
   begin
      if Set.Has_Element (Result.CM) then
         Result.Set := Self.Attributes.Constant_Reference (Result.CM).Element;

         --  If we have an attribute in the bucket let's check if the index
         --  is case sensitive or not.

         Result.CA := Result.Set.Find
           (Create (Index, Default_At_Pos => At_Pos));

         if not Set_Attribute.Has_Element (Result.CA) then
            Result.CA := Result.Set.Find
              (Create (Attribute_Index.Any, 0));
         end if;
      end if;

      return Result;
   end Find;

   -----------
   -- First --
   -----------

   overriding function First (Iter : Iterator) return Cursor is
      Position : Cursor :=
                   (CM  => Iter.Set.Attributes.First,
                    CA  => Set_Attribute.No_Element,
                    Set => null);
   begin
      if Set.Has_Element (Position.CM) then
         Position.Set :=
           Iter.Set.Attributes.Constant_Reference (Position.CM).Element;
         Position.CA := Position.Set.First;
      end if;

      if Has_Element (Position) and then not Is_Matching (Iter, Position) then
         return Next (Iter, Position);
      else
         return Position;
      end if;
   end First;

   -----------------
   -- Has_Element --
   -----------------

   function Has_Element (Position : Cursor) return Boolean is
   begin
      return Position.Set /= null
        and then Set_Attribute.Has_Element (Position.CA);
   end Has_Element;

   -------------
   -- Include --
   -------------

   procedure Include
     (Self : in out Object; Attribute : Project.Attribute.Object)
   is
      ---------------------
      -- To_Value_At_Pos --
      ---------------------

      function To_Value_At_Pos
        (Item : Attribute_Index.Object) return Value_At_Pos
      is
        (if Item.Is_Defined
         then Create (Item,
                      Default_At_Pos => At_Pos_Or (Item, 0))
         else (0, "", 0));
      --  Returns value as string together with 'at' part or empty if not
      --  defined.

      Position : constant Set.Cursor :=
                   Self.Attributes.Find (Attribute.Name.Text);
      Present  : Boolean := False;

   begin
      if Set.Has_Element (Position) then
         declare
            A : Set_Attribute.Map := Set.Element (Position);
         begin
            Present := A.Contains (To_Value_At_Pos (Attribute.Index));
            A.Include  (Attribute.Case_Aware_Index, Attribute);
            Self.Attributes.Replace_Element (Position, A);
         end;

      else
         declare
            A : Set_Attribute.Map;
         begin
            Present := A.Contains (To_Value_At_Pos (Attribute.Index));
            A.Include (Attribute.Case_Aware_Index, Attribute);
            Self.Attributes.Insert (Attribute.Name.Text, A);
         end;
      end if;

      if not Present then
         Self.Length := Self.Length + 1;
      end if;
   end Include;

   ------------
   -- Insert --
   ------------

   procedure Insert
     (Self : in out Object; Attribute : Project.Attribute.Object)
   is
      Position : constant Set.Cursor :=
                   Self.Attributes.Find (Attribute.Name.Text);
   begin
      if Set.Has_Element (Position) then
         Self.Attributes (Position).Insert
           (Attribute.Case_Aware_Index, Attribute);

      else
         declare
            A : Set_Attribute.Map;
         begin
            A.Insert (Attribute.Case_Aware_Index, Attribute);
            Self.Attributes.Insert (Attribute.Name.Text, A);
         end;
      end if;

      Self.Length := Self.Length + 1;
   end Insert;

   --------------
   -- Is_Empty --
   --------------

   function Is_Empty (Self : Object) return Boolean is
   begin
      return Self.Length = 0;
   end Is_Empty;

   -----------------
   -- Is_Matching --
   -----------------

   function Is_Matching
     (Iter : Iterator'Class; Position : Cursor) return Boolean
   is
      A    : constant Attribute.Object := Position.Set.all (Position.CA);
      Name : constant Optional_Name_Type :=
               Optional_Name_Type (To_String (Iter.Name));
   begin
      return
        (Name = No_Name or else A.Name.Text = Name_Type (Name))
        and then (not Iter.Index.Is_Defined
                  or else A.Index = Iter.Index)
        and then (Iter.With_Defaults or else not A.Is_Default);
   end Is_Matching;

   -------------
   -- Iterate --
   -------------

   function Iterate
     (Self            : Object;
      Name            : Optional_Name_Type     := No_Name;
      Index           : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos          : Natural                := 0;
      With_Defaults   : Boolean                := False)
      return Attribute_Iterator.Forward_Iterator'Class is
   begin
      return It : Iterator do
         It.Set           := Self;
         It.Name          := To_Unbounded_String (String (Name));
         It.Index         := Index;
         It.At_Pos        := At_Pos;
         It.With_Defaults := With_Defaults;
      end return;
   end Iterate;

   ------------
   -- Length --
   ------------

   function Length (Self : Object) return Containers.Count_Type is
   begin
      return Self.Length;
   end Length;

   ----------
   -- Next --
   ----------

   overriding function Next
     (Iter : Iterator; Position : Cursor) return Cursor
   is

      procedure Next (Position : in out Cursor)
        with Post => Position'Old /= Position;
      --  Move Position to next element

      ----------
      -- Next --
      ----------

      procedure Next (Position : in out Cursor) is
      begin
         Position.CA := Set_Attribute.Next (Position.CA);

         if not Set_Attribute.Has_Element (Position.CA) then
            Position.CM := Set.Next (Position.CM);

            if Set.Has_Element (Position.CM) then
               Position.Set :=
                 Iter.Set.Attributes.Constant_Reference (Position.CM).Element;
               Position.CA := Position.Set.First;

            else
               Position.Set := null;
            end if;
         end if;
      end Next;

      Result : Cursor := Position;
   begin
      loop
         Next (Result);
         exit when not Has_Element (Result) or else Is_Matching (Iter, Result);
      end loop;

      return Result;
   end Next;

   ---------------
   -- Reference --
   ---------------

   function Reference
     (Self     : aliased in out Object;
      Position : Cursor) return Reference_Type
   is
      pragma Unreferenced (Self);
   begin
      return Reference_Type'
        (Attribute =>
           Set_Attribute.Reference (Position.Set.all, Position.CA).Element);
   end Reference;

   ------------------
   -- Set_Defaults --
   ------------------

   procedure Set_Defaults
     (Self : in out Object;
      VDD  : Definition.Data;
      Pack : Optional_Name_Type)
   is
      package SR renames Source_Reference;

      Project_SRef        : constant SR.Object :=
                              SR.Object
                                (SR.Create
                                   (VDD.Trees.Project.Path_Name.Value, 0, 0));

      Standalone          : constant Source_Reference.Identifier.Object :=
                              Source_Reference.Identifier.Object
                                (Source_Reference.Identifier.Create
                                   (Project_SRef, RA.Library_Standalone));

      Standalone_Standard : constant Project.Attribute.Object :=
                              Project.Attribute.Create
                                (Standalone,
                                 Source_Reference.Value.Object
                                   (Source_Reference.Value.Create
                                      (Project_SRef, "Standard")),
                                 Default => True);

      Standalone_No       : constant Project.Attribute.Object :=
                              Project.Attribute.Create
                                (Standalone,
                                 Source_Reference.Value.Object
                                   (Source_Reference.Value.Create
                                      (Project_SRef, "No")),
                                 Default => True);

      Rules : constant RA.Default_Rules := RA.Get_Default_Rules (Pack);

      procedure Each_Default (Attr : Name_Type; Def : RA.Def);

      ------------------
      -- Each_Default --
      ------------------

      procedure Each_Default (Attr : Name_Type; Def : RA.Def) is
         use type RA.Index_Kind;

         procedure Gather (Def : RA.Def; Attrs : in out Set_Attribute.Map);

         function Attr_Id return SR.Identifier.Object is
           (SR.Identifier.Object (SR.Identifier.Create (Project_SRef, Attr)));

         function Create_Attribute
           (Index : Value_Type;
            Value : SR.Value.Object) return Attribute.Object;

         ----------------------
         -- Create_Attribute --
         ----------------------

         function Create_Attribute
           (Index : Value_Type;
            Value : SR.Value.Object) return Attribute.Object
         is
            Result : Attribute.Object;

            function Create_Index return Attribute_Index.Object is
              (if Def.Index = RA.No
               then Attribute_Index.Undefined
               else Attribute_Index.Create
                 (SR.Value.Object (SR.Value.Create (Project_SRef, Index)),
                  False, False));

         begin
            if Def.Value = List then
               Result := Project.Attribute.Create
                 (Name            => Attr_Id,
                  Index           => Create_Index,
                  Values          =>
                    Containers.Source_Value_Type_List.To_Vector (Value, 1),
                  Default         => True);

            else
               Result := Project.Attribute.Create
                 (Attr_Id, Create_Index, Value, Default => True);
            end if;

            Result.Set_Case
              (Index_Is_Case_Sensitive => Def.Index_Case_Sensitive,
               Value_Is_Case_Sensitive => Def.Value_Case_Sensitive);

            return Result;
         end Create_Attribute;

         ------------
         -- Gather --
         ------------

         procedure Gather (Def : RA.Def; Attrs : in out Set_Attribute.Map) is
            package VSR renames Containers.Name_Value_Map_Package;
         begin
            if Def.Index = RA.No and then not Attrs.Is_Empty then
               --  Attribute already exists

               pragma Assert
                 (Attrs.Length = 1, "Attribute map length" & Attrs.Length'Img);

               return;

            elsif Def.Default_Is_Reference then
               declare
                  Ref_Name : constant Name_Type :=
                               Name_Type (Def.Default.First_Element);
                  CS : constant Set.Cursor := Self.Attributes.Find (Ref_Name);
               begin
                  if Set.Has_Element (CS) then
                     for CA in Set.Element (CS).Iterate loop
                        if not Attrs.Contains (Set_Attribute.Key (CA)) then
                           Attrs.Insert
                             (Set_Attribute.Key (CA),
                              Set_Attribute.Element (CA).Rename (Attr_Id));
                        end if;
                     end loop;
                  end if;

                  Gather (RA.Get (RA.Create (Ref_Name, Pack)), Attrs);
               end;

            elsif not Def.Default.Is_Empty then
               for D in Def.Default.Iterate loop
                  if not Attrs.Contains
                    (Create (Value_Type (VSR.Key (D)), 0))
                  then
                     Attrs.Insert
                       (Create (Value_Type (VSR.Key (D)), 0),
                        Create_Attribute
                          (Value_Type (VSR.Key (D)),
                           SR.Value.Object
                             (SR.Value.Create (Project_SRef,
                              VSR.Element (D)))));
                  end if;
               end loop;
            end if;
         end Gather;

      begin
         if Def.Has_Default_In (VDD.Kind) then
            declare
               CM : constant Set.Cursor := Self.Attributes.Find (Attr);
               AM : Set_Attribute.Map;
            begin
               if Set.Has_Element (CM) then
                  Gather (Def, Self.Attributes (CM));

               else
                  Gather (Def, AM);

                  if not AM.Is_Empty then
                     Self.Attributes.Insert (Attr, AM);
                  end if;
               end if;
            end;
         end if;
      end Each_Default;

   begin
      RA.For_Each_Default (Rules, Each_Default'Access);

      --  Check for Library_Standalone special case has it has different
      --  default value in library project:
      --
      --  "standard" when Interface or Library_Interface is defined
      --  "no"       all other cases.

      if Pack = No_Name
        and then VDD.Kind in K_Library | K_Aggregate_Library
        and then not VDD.Attrs.Contains (RA.Library_Standalone)
      then
         if VDD.Attrs.Has_Interfaces
           or else VDD.Attrs.Has_Library_Interface
         then
            Self.Insert (Standalone_Standard);
         else
            Self.Insert (Standalone_No);
         end if;
      end if;
   end Set_Defaults;

begin
   Definition.Set_Defaults := Set_Defaults'Access;
end GPR2.Project.Attribute.Set;
