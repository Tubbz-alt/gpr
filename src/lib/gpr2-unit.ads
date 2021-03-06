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

--  This package represents an Ada Unit in the sense of the Ada
--  grammar. An Ada source may be multi-unit (versus single-unit) i.e. define
--  more than one such compilation units, each one having its own set of with
--  clauses. The list of those compilation units for the source is kept in
--  Source.Registry.
--
--  Each Unit object has the following data:
--     - The name of the unit it refers to
--     - Its index in the compilation units that the source contains,
--       starting from 1
--     - The kind of definition it provides for the unit: either it is the
--       unit's specification, main body, or a separate body.
--     - Its with clauses, represented as Source_Reference.Identifier objects
--       (withed package name + source location)
--     - The name of the unit it is a separate from, if it's a separate
--
--  For instance, if source S has the following content:
--
--     with Foo;
--     package body Pkg is
--        [...]
--     end Pkg;
--
--     with Bar;
--     separate (A) procedure Proc is
--        [...]
--     end Proc;
--
--  Then two compilation units will be stored in the registry entry for S:
--     { (Unit_Name => Pkg, Index => 1, Kind => S_Body,
--        Withed_Units => {Foo}, Is_Sep_From => -),
--       (Unit_Name => Proc, Index => 2, Kind => S_Separate,
--        Withed_Units => {Bar}, Is_Sep_From => A) }

with GPR2.Source_Reference.Identifier.Set;

package GPR2.Unit is

   type Object is tagged private;

   Undefined : constant Object;
   --  This constant is equal to any object declared without an explicit
   --  initializer.

   type Library_Unit_Type is
     (S_Spec, S_Spec_Only, S_Body, S_Body_Only, S_Separate);
   --  Indicates type of unit, if both body and spec are present, then the
   --  first unit is marked S_Body, and the second is marked S_Spec. If only
   --  a spec appears, then it is marked as S_Spec_Only, and if only a body
   --  appears, then it is marked S_Body_Only).

   subtype Spec_Kind is Library_Unit_Type range S_Spec .. S_Spec_Only;
   subtype Body_Kind is Library_Unit_Type range S_Body .. S_Body_Only;

   type Library_Item_Type is (Is_Package, Is_Subprogram);
   --  Indicates whether a library item is a package or a subprogram

   type Main_Type is (None, Is_Procedure, Is_Function);

   type Flag is
     (Preelab,
      No_Elab_Code,
      Pure,
      Dynamic_Elab,
      Elaborate_Body,
      Has_RACW,
      Remote_Types,
      Shared_Passive,
      RCI,
      Predefined,
      Is_Generic,
      Init_Scalars,
      SAL_Interface,
      Body_Needed_For_SAL,
      Elaborate_Body_Desirable);
   --  Flags that can appear on a unit line

   type Flags_Set is array (Flag) of Boolean with Pack;
   --  Set of flags applying to a given unit

   Default_Flags : constant Flags_Set;

   function Create
     (Name          : Name_Type;
      Index         : Positive;
      Lib_Unit_Kind : Library_Unit_Type;
      Lib_Item_Kind : Library_Item_Type;
      Main          : Main_Type;
      Dependencies  : Source_Reference.Identifier.Set.Object;
      Sep_From      : Optional_Name_Type;
      Flags         : Flags_Set) return Object
     with Post => Create'Result.Is_Defined;
   --  Create a compilation unit object

   function Is_Defined (Self : Object) return Boolean;
   --  Returns True if Self is defined

   function Name (Self : Object) return Name_Type
     with Pre => Self.Is_Defined;
   --  Returns the unit name for this compilation unit

   function Index (Self : Object) return Positive
     with Pre => Self.Is_Defined;
   --  Returns the source index for this compilation unit

   function Kind (Self : Object) return Library_Unit_Type
     with Pre => Self.Is_Defined;
   --  Returns the kind for this compilation unit

   function Library_Item_Kind (Self : Object) return Library_Item_Type
     with Pre => Self.Is_Defined;
   --  Returns the library type, i.e is the unit package or subroutine

   function Dependencies
     (Self : Object) return Source_Reference.Identifier.Set.Object
     with Pre => Self.Is_Defined;
   --  Returns the set of withed units for this compilation unit

   function Is_Separate (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if Self is a separate

   function Is_Flag_Set (Self : Object; Item : Flag) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if Flag is set

   function Is_Any_Flag_Set (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if any Flag is set

   function Separate_From (Self : Object) return Name_Type
     with Pre => Self.Is_Defined and then Self.Is_Separate;
   --  Returns the parent unit name for Self separate unit

   function Is_Generic (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if Self is a generic unit

   procedure Update_Kind (Self : in out Object; Kind : Library_Unit_Type)
     with Pre  => Self.Is_Defined,
          Post => Self.Kind = Kind;
   --  Update kind for this unit

   procedure Set_Separate_From (Self : in out Object; Name : Name_Type)
     with Pre  => Self.Is_Defined,
          Post => Self.Kind = S_Separate;
   --  Set subunit to be separate from Name

   function Image (Item : Flag) return String;
   --  Returns a string representation of Flag

private

   Default_Flags : constant Flags_Set := (others => False);

   type Object is tagged record
      Name         : Unbounded_String;
      Index        : Natural           := 0;
      Kind         : Library_Unit_Type := S_Spec;
      Item_Kind    : Library_Item_Type := Is_Package;
      Main         : Main_Type         := None;
      Dependencies : Source_Reference.Identifier.Set.Object;
      Sep_From     : Unbounded_String;
      Flags        : Flags_Set := Default_Flags;
   end record
     with Dynamic_Predicate =>
       (Length (Sep_From) > 0) = (Kind = S_Separate);
   --  Note that in GPR2 we have a distinction between sources, that may
   --  define either the spec or body/ies for a unit - those definitions are
   --  represented as Compil_Unit records, and the unit itself which
   --  is just a name (the Unit_Name).

   Undefined : constant Object := (others => <>);

   function Create
     (Name          : Name_Type;
      Index         : Positive;
      Lib_Unit_Kind : Library_Unit_Type;
      Lib_Item_Kind : Library_Item_Type;
      Main          : Main_Type;
      Dependencies  : Source_Reference.Identifier.Set.Object;
      Sep_From      : Optional_Name_Type;
      Flags         : Flags_Set) return Object is
     (Object'(Name         => To_Unbounded_String (String (Name)),
              Index        => Index,
              Kind         => Lib_Unit_Kind,
              Item_Kind    => Lib_Item_Kind,
              Main         => Main,
              Dependencies => Dependencies,
              Sep_From     => To_Unbounded_String (String (Sep_From)),
              Flags        => Flags));

   function Name (Self : Object) return Name_Type is
     (Name_Type (To_String (Self.Name)));

   function Index (Self : Object) return Positive is
     (Self.Index);

   function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

   function Is_Separate (Self : Object) return Boolean is
     (Self.Kind = S_Separate);

   function Separate_From (Self : Object) return Name_Type is
     (Name_Type (To_String (Self.Sep_From)));

   function Kind (Self : Object) return Library_Unit_Type is
     (Self.Kind);

   function Library_Item_Kind (Self : Object) return Library_Item_Type is
      (Self.Item_Kind);

   function Dependencies
     (Self : Object) return Source_Reference.Identifier.Set.Object
   is
     (Self.Dependencies);

   function Is_Generic (Self : Object) return Boolean is
      (Self.Flags (Is_Generic));

   function Is_Flag_Set (Self : Object; Item : Flag) return Boolean is
      (Self.Flags (Item));

   function Is_Any_Flag_Set (Self : Object) return Boolean is
      (Self.Flags /= (Flag'Range => False));

   function Image (Item : Flag) return String is
     (case Item is
         when Preelab                  => "Preelaborable",
         when No_Elab_Code             => "No_Elab_Code",
         when Pure                     => "Pure",
         when Dynamic_Elab             => "Dynamic_Elab",
         when Elaborate_Body           => "Elaborate_Body",
         when Has_RACW                 => "Has_RACW",
         when Remote_Types             => "Remote_Types",
         when Shared_Passive           => "Shared_Passive",
         when RCI                      => "RCI",
         when Predefined               => "Predefined",
         when Is_Generic               => "Is_Generic",
         when Init_Scalars             => "Init_Scalars",
         when SAL_Interface            => "SAL_Interface",
         when Body_Needed_For_SAL      => "Body_Needed_For_SAL",
         when Elaborate_Body_Desirable => "Elaborate_Body_Desirable");

end GPR2.Unit;
