
------------------------------------------------------------------------------
--                                                                          --
--                            GPR PROJECT PARSER                            --
--                                                                          --
--            Copyright (C) 2015-2016, Free Software Foundation, Inc.       --
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

--  DO NOT EDIT THIS IS AN AUTOGENERATED FILE


with Ada.Containers.Hashed_Maps;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;

with System;

with Langkit_Support.Bump_Ptr;           use Langkit_Support.Bump_Ptr;
with Langkit_Support.Diagnostics;        use Langkit_Support.Diagnostics;
with Langkit_Support.Symbols;            use Langkit_Support.Symbols;
with Langkit_Support.Vectors;

with GPR_Parser.Analysis_Interfaces;
use GPR_Parser.Analysis_Interfaces;
with GPR_Parser.AST;
use GPR_Parser.AST;
with GPR_Parser.Lexer;
use GPR_Parser.Lexer.Token_Data_Handlers;

--  This package provides types and primitives to analyze source files as
--  analysis units.
--
--  This is the entry point to parse and process an unit: first create an
--  analysis context with Create, then get analysis units out of it using
--  Get_From_File and/or Get_From_Buffer.

package GPR_Parser.Analysis is

   ----------------------
   -- Analysis context --
   ----------------------

   type Analysis_Context is private;
   --  Context for all source analysis.

   type Analysis_Unit is private;
   --  Context for the analysis of a single compilation unit. References are
   --  ref-counted.

   type Grammar_Rule is (
         Abstract_Present_Rule
            ,
         Associative_Array_Index_Rule
            ,
         Attribute_Decl_Rule
            ,
         Attribute_Reference_Rule
            ,
         Case_Construction_Rule
            ,
         Case_Item_Rule
            ,
         Choice_Rule
            ,
         Compilation_Unit_Rule
            ,
         Context_Clauses_Rule
            ,
         Declarative_Item_Rule
            ,
         Declarative_Items_Rule
            ,
         Discrete_Choice_List_Rule
            ,
         Empty_Declaration_Rule
            ,
         Expression_Rule
            ,
         Expression_List_Rule
            ,
         External_Rule
            ,
         External_As_List_Rule
            ,
         External_Name_Rule
            ,
         External_Reference_Rule
            ,
         Identifier_Rule
            ,
         Num_Literal_Rule
            ,
         Others_Designator_Rule
            ,
         Package_Decl_Rule
            ,
         Package_Extension_Rule
            ,
         Package_Renaming_Rule
            ,
         Package_Spec_Rule
            ,
         Project_Rule
            ,
         Project_Declaration_Rule
            ,
         Project_Extension_Rule
            ,
         Project_Qualifier_Rule
            ,
         Project_Reference_Rule
            ,
         Qualifier_Names_Rule
            ,
         Simple_Declarative_Item_Rule
            ,
         Simple_Declarative_Items_Rule
            ,
         Static_Name_Rule
            ,
         String_Literal_Rule
            ,
         String_Literal_At_Rule
            ,
         Term_Rule
            ,
         Typed_String_Decl_Rule
            ,
         Variable_Decl_Rule
            ,
         Variable_Reference_Rule
            ,
         With_Decl_Rule
   );
   --  Gramar rule to use for parsing.

   function Create
     (Charset : String := "utf-8")
      return Analysis_Context;
   --  Create a new Analysis_Context. The returned value has a ref-count set to
   --  1. When done with it, invoke Destroy on it, in which case the ref-count
   --  is ignored. If this value is shared with garbage collected languages,
   --  use ref-counting primitives instead so that the context is destroyed
   --  when nobody references it anymore.
   --
   --  Charset will be used as a default charset to decode input sources in
   --  analysis units. Please see GNATCOLL.Iconv for a couple of supported
   --  charsets. Be careful: passing an unsupported charset here is not
   --  guaranteed to raise an error here.
   --
   --  ??? Passing an unsupported charset here is not guaranteed to raise an
   --  error right here, but this would be really helpful for users.

   procedure Inc_Ref (Context : Analysis_Context);
   --  Increase the reference count to an analysis context. Useful for bindings to
--  garbage collected languages.

   procedure Dec_Ref (Context : in out Analysis_Context);
   --  Decrease the reference count to an analysis context. Useful for bindings to
--  garbage collected languages. Destruction happens when the ref-count reaches
--  0.

   function Get_From_File
     (Context     : Analysis_Context;
      Filename    : String;
      Charset     : String := "";
      Reparse     : Boolean := False;
      With_Trivia : Boolean := False;
      Rule        : Grammar_Rule :=
         Compilation_Unit_Rule)
      return Analysis_Unit;
   --  Create a new analysis unit for Filename or return the existing one if
   --  any. If Reparse is true and the analysis unit already exists, reparse it
   --  from Filename.
   --
   --  The result is owned by the context: the caller must increase its ref-
   --  count in order to keep a reference to it.
   --
   --  Rule controls which grammar rule is used to parse the unit.
   --
   --  ??? export this feature to the C and Python APIs.
   --
   --  Use Charset in order to decode the content of Filename. If Charset is
   --  empty then use the last charset used for this unit, or use the context's
   --  default if creating this unit.
   --
   --  If any failure occurs, such as file opening, decoding, lexing or parsing
   --  failure, return an analysis unit anyway: errors are described as
   --  diagnostics.
   --
   --  When With_Trivia is true, the parsed analysis unit will contain trivias.
   --  Already existing analysis units are reparsed if needed.

   function Get_From_Buffer
     (Context     : Analysis_Context;
      Filename    : String;
      Charset     : String := "";
      Buffer      : String;
      With_Trivia : Boolean := False;
      Rule        : Grammar_Rule :=
         Compilation_Unit_Rule)
      return Analysis_Unit;
   --  Create a new analysis unit for Filename or return the existing one if
   --  any. Whether the analysis unit already exists or not, (re)parse it from
   --  the source code in Buffer.
   --
   --  The result is owned by the context: the caller must increase its ref-
   --  count in order to keep a reference to it.
   --
   --  Use Charset in order to decode the content of Filename. If Charset is
   --  empty then use the last charset used for this unit, or use the context's
   --  default if creating this unit.
   --
   --  If any failure occurs, such as decoding, lexing or parsing failure,
   --  return an analysis unit anyway: errors are described as diagnostics.
   --
   --  When With_Trivia is true, the parsed analysis unit will contain trivias.
   --  Already existing analysis units are reparsed if needed.

   procedure Remove (Context   : Analysis_Context;
                     File_Name : String);
   --  Remove the corresponding analysis unit from this context. If someone
   --  still owns a reference to it, it remains available but becomes context-
   --  less.
   --
   --  If there is no such analysis unit, raise a Constraint_Error exception.

   procedure Destroy (Context : in out Analysis_Context);
   --  Invoke Remove on all the units Context contains and free Context. Thus,
   --  any analysis unit it contains may survive if there are still references
   --  to it elsewhere.

   procedure Inc_Ref (Unit : Analysis_Unit);
   --  Increase the reference count to an analysis unit.

   procedure Dec_Ref (Unit : Analysis_Unit);
   --  Decrease the reference count to an analysis unit.

   function Get_Context (Unit : Analysis_Unit) return Analysis_Context;
   --  Return the context that owns this unit.

   procedure Reparse (Unit : Analysis_Unit; Charset : String := "");
   --  Reparse an analysis unit from the associated file. If Charset is empty
   --  or null, use the last charset successfuly used for this unit, otherwise
   --  use it to decode the content of Filename.
   --
   --  If any failure occurs, such as decoding, lexing or parsing failure,
   --  diagnostic are emitted to explain what happened.

   procedure Reparse
     (Unit    : Analysis_Unit;
      Charset : String := "";
      Buffer  : String);
   --  Reparse an analysis unit from a buffer. If Charset is empty or null, use
   --  the last charset successfuly used for this unit, otherwise use it to
   --  decode the content of Filename.
   --
   --  If any failure occurs, such as decoding, lexing or parsing failure,
   --  diagnostic are emitted to explain what happened.

   procedure Populate_Lexical_Env (Unit : Analysis_Unit);
   --  Populate the lexical environments for this analysis unit, according to the
--  specifications given in the language spec.

   function Get_Filename (Unit : Analysis_Unit) return String;
   --  Return the filename an unit is associated to.

   function Has_Diagnostics (Unit : Analysis_Unit) return Boolean;
   --  Return whether this unit has associated diagnostics.

   function Diagnostics (Unit : Analysis_Unit) return Diagnostics_Array;
   --  Return an array that contains the diagnostics associated to this unit.

   function Root (Unit : Analysis_Unit) return GPR_Node;
   --  Return the root AST node for this unit, or null if there is none.

   function Get_Unit
     (Node : access GPR_Node_Type'Class)
      return Analysis_Unit;
   --  Return the unit that owns an AST node.

   function First_Token (Unit : Analysis_Unit) return Token_Type;
   --  Return a reference to the first token scanned in this unit.

   function Last_Token (Unit : Analysis_Unit) return Token_Type;
   --  Return a reference to the last token scanned in this unit.

   procedure Dump_Lexical_Env (Unit : Analysis_Unit);
   --  Debug helper: output the lexical envs for given analysis unit

   procedure Print (Unit : Analysis_Unit);
   --  Debug helper: output the AST and eventual diagnostic for this unit on
   --  standard output.

   procedure PP_Trivia (Unit : Analysis_Unit);
   --  Debug helper: output a minimal AST with mixed trivias

private

   type Analysis_Context_Type;
   type Analysis_Unit_Type;

   type Analysis_Context is access all Analysis_Context_Type;
   type Analysis_Unit is access all Analysis_Unit_Type;

   package Units_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unbounded_String,
      Element_Type    => Analysis_Unit,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => "=");

   type Analysis_Context_Type is record
      Ref_Count  : Natural;
      Units_Map  : Units_Maps.Map;
      Symbols    : Symbol_Table;

      Charset    : Unbounded_String;
      --  Default charset to use in analysis units

      Root_Scope : AST_Envs.Lexical_Env;
      --  The lexical scope that is shared amongst every compilation unit. Used
      --  to resolve cross file references.
   end record;

   type Destroyable_Type is record
      Object  : System.Address;
      --  Object to destroy

      Destroy : Destroy_Procedure;
      --  Procedure to destroy Object
   end record;
   --  Simple holder to associate an object to destroy and the procedure to
   --  perform the destruction.

   package Destroyable_Vectors is new Langkit_Support.Vectors
     (Destroyable_Type);

   type Analysis_Unit_Type is new Analysis_Unit_Interface_Type with
   record
      Context          : Analysis_Context;
      Ref_Count        : Natural;
      AST_Root         : GPR_Node;
      File_Name        : Unbounded_String;
      Charset          : Unbounded_String;
      TDH              : aliased Token_Data_Handler;
      Diagnostics      : Diagnostics_Vectors.Vector;
      With_Trivia      : Boolean;

      Is_Env_Populated : Boolean;
      --  Whether Populate_Lexical_Env was called on this unit. Used not to
      --  populate multiple times the same unit and hence avoid infinite
      --  populate recursions for circular dependencies.

      Rule             : Grammar_Rule;
      --  The grammar rule used to parse this unit

      AST_Mem_Pool     : Bump_Ptr_Pool;
      --  This memory pool shall only be used for AST parsing. Stored here
      --  because it is more convenient, but one shall not allocate from it.

      Destroyables     : Destroyable_Vectors.Vector;
      --  Collection of objects to destroy when destroying the analysis unit
   end record;

   overriding
   function Token_Data
     (Unit : access Analysis_Unit_Type)
      return Token_Data_Handler_Access
   is
     (Unit.TDH'Access);

   overriding
   procedure Register_Destroyable_Helper
     (Unit    : access Analysis_Unit_Type;
      Object  : System.Address;
      Destroy : Destroy_Procedure);

   function Root (Unit : Analysis_Unit) return GPR_Node is
     (Unit.AST_Root);

   function Get_Context (Unit : Analysis_Unit) return Analysis_Context is
     (Unit.Context);

   function Get_Filename (Unit : Analysis_Unit) return String is
     (To_String (Unit.File_Name));

   function First_Token (Unit : Analysis_Unit) return Token_Type is
     (First_Token (Unit.TDH'Access));

   function Last_Token (Unit : Analysis_Unit) return Token_Type is
     (Last_Token (Unit.TDH'Access));

end GPR_Parser.Analysis;
