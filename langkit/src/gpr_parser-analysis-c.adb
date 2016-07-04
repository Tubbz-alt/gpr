
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




pragma Warnings (Off, "is an internal GNAT unit");
with Ada.Strings.Wide_Wide_Unbounded.Aux;
use Ada.Strings.Wide_Wide_Unbounded.Aux;
pragma Warnings (On, "is an internal GNAT unit");

with System.Memory;

with GNATCOLL.Iconv;

with Langkit_Support.Diagnostics; use Langkit_Support.Diagnostics;
with Langkit_Support.Extensions;  use Langkit_Support.Extensions;
with Langkit_Support.Text;        use Langkit_Support.Text;

with GPR_Parser.Analysis;
use GPR_Parser.Analysis;
with GPR_Parser.AST;
use GPR_Parser.AST;
with GPR_Parser.AST.C;
use GPR_Parser.AST.C;
with GPR_Parser.Lexer;
use GPR_Parser.Lexer;

package body GPR_Parser.Analysis.C is

   function Value_Or_Empty (S : chars_ptr) return String
   --  If S is null, return an empty string. Return Value (S) otherwise.
   is (if S = Null_Ptr
       then ""
       else Value (S));

   Last_Exception : gpr_exception_Ptr := null;

   ----------
   -- Free --
   ----------

   procedure Free (Address : System.Address) is
      procedure C_Free (Address : System.Address)
        with Import        => True,
             Convention    => C,
             External_Name => "free";
   begin
      C_Free (Address);
   end Free;

   -------------------------
   -- Analysis primitives --
   -------------------------

   function gpr_create_analysis_context
     (Charset : chars_ptr)
      return gpr_analysis_context
   is
   begin
      Clear_Last_Exception;

      declare
         C : constant String := (if Charset = Null_Ptr
                                 then ""
                                 else Value (Charset));
      begin
         return Wrap (if C'Length = 0
                      then Create
                      else Create (C));
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_analysis_context (System.Null_Address);
   end;

   function gpr_context_incref
     (Context : gpr_analysis_context)
      return gpr_analysis_context
   is
      C : constant Analysis_Context := Unwrap (Context);
   begin
      Inc_Ref (C);
      return Context;
   end;

   procedure gpr_context_decref
     (Context : gpr_analysis_context)
   is
      C : Analysis_Context := Unwrap (Context);
   begin
      Dec_Ref (C);
   end;

   procedure gpr_destroy_analysis_context
     (Context : gpr_analysis_context)
   is
   begin
      Clear_Last_Exception;

      declare
         C : Analysis_Context := Unwrap (Context);
      begin
         Destroy (C);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
   end;

   function gpr_get_analysis_unit_from_file
     (Context           : gpr_analysis_context;
      Filename, Charset : chars_ptr;
      Reparse           : int;
      With_Trivia       : int)
      return gpr_analysis_unit
   is
   begin
      Clear_Last_Exception;

      declare
         Ctx  : constant Analysis_Context := Unwrap (Context);
         Unit : constant Analysis_Unit := Get_From_File
           (Ctx,
            Value (Filename),
            Value_Or_Empty (Charset),
            Reparse /= 0,
            With_Trivia /= 0);
      begin
         return Wrap (Unit);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_analysis_unit (System.Null_Address);
   end;

   function gpr_get_analysis_unit_from_buffer
     (Context           : gpr_analysis_context;
      Filename, Charset : chars_ptr;
      Buffer            : chars_ptr;
      Buffer_Size       : size_t;
      With_Trivia       : int)
      return gpr_analysis_unit
   is
   begin
      Clear_Last_Exception;

      declare
         Ctx : constant Analysis_Context := Unwrap (Context);
         Unit : Analysis_Unit;

         Buffer_Str : String (1 .. Positive (Buffer_Size));
         for Buffer_Str'Address use Convert (Buffer);
      begin
         Unit := Get_From_Buffer
           (Ctx,
            Value (Filename),
            Value_Or_Empty (Charset),
            Buffer_Str,
            With_Trivia /= 0);
         return Wrap (Unit);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_analysis_unit (System.Null_Address);
   end;

   function gpr_remove_analysis_unit
     (Context  : gpr_analysis_context;
      Filename : chars_ptr) return int
   is
   begin
      Clear_Last_Exception;

      declare
         Ctx : constant Analysis_Context := Unwrap (Context);
      begin
         begin
            Remove (Ctx, Value (Filename));
         exception
            when Constraint_Error =>
               return 0;
         end;
         return 1;
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return 0;
   end;

   function gpr_unit_root (Unit : gpr_analysis_unit)
                                           return gpr_base_node
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
      begin
         return Wrap (U.AST_Root);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_base_node (System.Null_Address);
   end;

   procedure gpr_unit_first_token
     (Unit  : gpr_analysis_unit;
      Token : gpr_token_Ptr)
   is
      U : constant Analysis_Unit := Unwrap (Unit);
      T : constant Token_Type := First_Token (U);
   begin
      Token.all := Wrap (T);
   end;

   procedure gpr_unit_last_token
     (Unit  : gpr_analysis_unit;
      Token : gpr_token_Ptr)
   is
      U : constant Analysis_Unit := Unwrap (Unit);
      T : constant Token_Type := Last_Token (U);
   begin
      Token.all := Wrap (T);
   end;

   function gpr_unit_filename
     (Unit : gpr_analysis_unit)
      return chars_ptr
   is
      U : constant Analysis_Unit := Unwrap (Unit);
   begin
      return New_String (Get_Filename (U));
   end;

   function gpr_unit_diagnostic_count
     (Unit : gpr_analysis_unit) return unsigned
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
      begin
         return unsigned (U.Diagnostics.Length);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return 0;
   end;

   function gpr_unit_diagnostic
     (Unit         : gpr_analysis_unit;
      N            : unsigned;
      Diagnostic_P : gpr_diagnostic_Ptr) return int
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
      begin
         if N < unsigned (U.Diagnostics.Length) then
            declare
               D_In  : Diagnostic renames U.Diagnostics (Natural (N) + 1);
               D_Out : gpr_diagnostic renames Diagnostic_P.all;
            begin
               D_Out.Sloc_Range := Wrap (D_In.Sloc_Range);
               D_Out.Message := Wrap (D_In.Message);
               return 1;
            end;
         else
            return 0;
         end if;
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return 0;
   end;

   function gpr_node_unit
     (Node : gpr_base_node)
      return gpr_analysis_unit
   is
   begin
      Clear_Last_Exception;

      declare
         N : constant GPR_Node := Unwrap (Node);
         U : constant Analysis_Unit := Get_Unit (N);
      begin
         return Wrap (U);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_analysis_unit (System.Null_Address);
   end;

   function gpr_unit_incref
     (Unit : gpr_analysis_unit) return gpr_analysis_unit
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
      begin
         Inc_Ref (U);
         return Unit;
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_analysis_unit (System.Null_Address);
   end;

   procedure gpr_unit_decref (Unit : gpr_analysis_unit)
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
      begin
         Dec_Ref (U);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
   end;

   function gpr_unit_context
     (Unit : gpr_analysis_unit)
      return gpr_analysis_context
   is
      U : constant Analysis_Unit := Unwrap (Unit);
   begin
      return Wrap (U.Context);
   end;

   procedure gpr_unit_reparse_from_file
     (Unit : gpr_analysis_unit; Charset : chars_ptr)
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
      begin
         Reparse (U, Value_Or_Empty (Charset));
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
   end;

   procedure gpr_unit_reparse_from_buffer
     (Unit        : gpr_analysis_unit;
      Charset     : chars_ptr;
      Buffer      : chars_ptr;
      Buffer_Size : size_t)
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
         Buffer_Str : String (1 .. Positive (Buffer_Size));
         for Buffer_Str'Address use Convert (Buffer);
      begin
         Reparse (U, Value_Or_Empty (Charset), Buffer_Str);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
   end;

   procedure gpr_unit_populate_lexical_env
     (Unit : gpr_analysis_unit)
   is
   begin
      Clear_Last_Exception;

      declare
         U : constant Analysis_Unit := Unwrap (Unit);
      begin
         Populate_Lexical_Env (U);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
   end;

   ---------------------------------
   -- General AST node primitives --
   ---------------------------------

   Node_Kind_Names : constant array (GPR_Node_Kind_Type) of Text_Access :=
     (GPR_List => new Text_Type'(To_Text ("list"))
            , GPR_Abstract_Present =>
               new Text_Type'(To_Text ("AbstractPresent"))
            , GPR_Attribute_Decl =>
               new Text_Type'(To_Text ("AttributeDecl"))
            , GPR_Attribute_Reference =>
               new Text_Type'(To_Text ("AttributeReference"))
            , GPR_Case_Construction =>
               new Text_Type'(To_Text ("CaseConstruction"))
            , GPR_Case_Item =>
               new Text_Type'(To_Text ("CaseItem"))
            , GPR_Compilation_Unit =>
               new Text_Type'(To_Text ("CompilationUnit"))
            , GPR_Empty_Decl =>
               new Text_Type'(To_Text ("EmptyDecl"))
            , GPR_Prefix =>
               new Text_Type'(To_Text ("Prefix"))
            , GPR_Identifier =>
               new Text_Type'(To_Text ("Identifier"))
            , GPR_Num_Literal =>
               new Text_Type'(To_Text ("NumLiteral"))
            , GPR_String_Literal =>
               new Text_Type'(To_Text ("StringLiteral"))
            , GPR_Expr_List =>
               new Text_Type'(To_Text ("ExprList"))
            , GPR_External =>
               new Text_Type'(To_Text ("External"))
            , GPR_External_As_List =>
               new Text_Type'(To_Text ("ExternalAsList"))
            , GPR_External_Name =>
               new Text_Type'(To_Text ("ExternalName"))
            , GPR_External_Reference =>
               new Text_Type'(To_Text ("ExternalReference"))
            , GPR_Others_Designator =>
               new Text_Type'(To_Text ("OthersDesignator"))
            , GPR_Package_Decl =>
               new Text_Type'(To_Text ("PackageDecl"))
            , GPR_Package_Extension =>
               new Text_Type'(To_Text ("PackageExtension"))
            , GPR_Package_Renaming =>
               new Text_Type'(To_Text ("PackageRenaming"))
            , GPR_Package_Spec =>
               new Text_Type'(To_Text ("PackageSpec"))
            , GPR_Project =>
               new Text_Type'(To_Text ("Project"))
            , GPR_Project_Declaration =>
               new Text_Type'(To_Text ("ProjectDeclaration"))
            , GPR_Project_Extension =>
               new Text_Type'(To_Text ("ProjectExtension"))
            , GPR_Project_Qualifier =>
               new Text_Type'(To_Text ("ProjectQualifier"))
            , GPR_Project_Reference =>
               new Text_Type'(To_Text ("ProjectReference"))
            , GPR_Qualifier_Names =>
               new Text_Type'(To_Text ("QualifierNames"))
            , GPR_String_Literal_At =>
               new Text_Type'(To_Text ("StringLiteralAt"))
            , GPR_Term_List =>
               new Text_Type'(To_Text ("TermList"))
            , GPR_Typed_String_Decl =>
               new Text_Type'(To_Text ("TypedStringDecl"))
            , GPR_Variable_Decl =>
               new Text_Type'(To_Text ("VariableDecl"))
            , GPR_Variable_Reference =>
               new Text_Type'(To_Text ("VariableReference"))
            , GPR_With_Decl =>
               new Text_Type'(To_Text ("WithDecl"))
      );

   function gpr_node_kind (Node : gpr_base_node)
      return gpr_node_kind_enum
   is
   begin
      Clear_Last_Exception;

      declare
         N : constant GPR_Node := Unwrap (Node);
         K : GPR_Node_Kind_Type := Kind (N);
      begin
         return gpr_node_kind_enum (K'Enum_Rep);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_node_kind_enum'First;
   end;

   function gpr_kind_name (Kind : gpr_node_kind_enum)
                                           return gpr_text
   is
   begin
      Clear_Last_Exception;

      declare
         K    : constant GPR_Node_Kind_Type :=
            GPR_Node_Kind_Type'Enum_Val (Kind);
         Name : Text_Access renames Node_Kind_Names (K);
      begin
         return (Chars => Name.all'Address, Length => Name'Length,
                 Is_Allocated => 0);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return (System.Null_Address, 0, Is_Allocated => 0);
   end;

   function gpr_node_short_image (Node : gpr_base_node)
                                                  return gpr_text
   is
   begin
      Clear_Last_Exception;
      declare
         N   : constant GPR_Node := Unwrap (Node);
         Img : constant Text_Type := N.Short_Image;
      begin
         return Wrap_Alloc (Img);
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return (System.Null_Address, 0, 0);
   end;

   procedure gpr_node_sloc_range
     (Node         : gpr_base_node;
      Sloc_Range_P : gpr_source_location_range_Ptr)
   is
   begin
      Clear_Last_Exception;

      declare
         N : constant GPR_Node := Unwrap (Node);
      begin
         Sloc_Range_P.all := Wrap (Sloc_Range (N));
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
   end;

   function gpr_lookup_in_node
     (Node : gpr_base_node;
      Sloc : gpr_source_location_Ptr) return gpr_base_node
   is
   begin
      Clear_Last_Exception;

      declare
         N : constant GPR_Node := Unwrap (Node);
         S : constant Source_Location := Unwrap (Sloc.all);
      begin
         return Wrap (Lookup (N, S));
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return gpr_base_node (System.Null_Address);
   end;

   function gpr_node_child_count (Node : gpr_base_node)
                                                  return unsigned
   is
   begin
      Clear_Last_Exception;

      declare
         N : constant GPR_Node := Unwrap (Node);
      begin
         return unsigned (Child_Count (N));
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return 0;
   end;

   function gpr_node_child
     (Node    : gpr_base_node;
      N       : unsigned;
      Child_P : gpr_base_node_Ptr) return int
   is
   begin
      Clear_Last_Exception;

      declare
         Nod    : constant GPR_Node := Unwrap (Node);
         Result : GPR_Node;
         Exists : Boolean;
      begin
         if N > unsigned (Natural'Last) then
            return 0;
         end if;
         Get_Child (Nod, Natural (N) + 1, Exists, Result);
         if Exists then
            Child_P.all := Wrap (Result);
            return 1;
         else
            return 0;
         end if;
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return 0;
   end;

   function gpr_text_to_locale_string
     (Text : gpr_text) return System.Address
   is
   begin
      Clear_Last_Exception;

      declare
         use GNATCOLL.Iconv;

         Input_Byte_Size : constant size_t := 4 * Text.Length;

         Output_Byte_Size : constant size_t := Input_Byte_Size + 1;
         --  Assuming no encoding will take more than 4 bytes per character, 4
         --  times the size of the input text plus one null byte should be
         --  enough to hold the result. This is a development helper anyway, so
         --  we don't have performance concerns.

         Result : constant System.Address := System.Memory.Alloc
           (System.Memory.size_t (Output_Byte_Size));
         --  Buffer we are going to return to the caller. We use
         --  System.Memory.Alloc so that users can call C's "free" function in
         --  order to free it.

         Input : String (1 .. Natural (Input_Byte_Size));
         for Input'Address use Text.Chars;

         Output : String (1 .. Natural (Output_Byte_Size));
         for Output'Address use Result;

         State                     : Iconv_T;
         Input_Index, Output_Index : Positive := 1;
         Status                    : Iconv_Result;

         From_Code : constant String :=
           (if System."=" (System.Default_Bit_Order, System.Low_Order_First)
            then UTF32LE
            else UTF32BE);

      begin
         --  GNATCOLL.Iconv raises Constraint_Error exceptions for empty
         --  strings, so handle them ourselves.

         if Input_Byte_Size = 0 then
            Output (1) := ASCII.NUL;
         end if;

         --  Encode to the locale. Don't bother with error checking...

         Set_Locale;
         State := Iconv_Open
           (To_Code         => Locale,
            From_Code       => From_Code,
            Transliteration => True,
            Ignore          => True);
         Iconv (State, Input, Input_Index, Output, Output_Index, Status);
         Iconv_Close (State);

         --  Don't forget the trailing NULL character to keep C programs happy
         Output (Output_Index) := ASCII.NUL;

         return Result;
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return System.Null_Address;
   end;

   -------------------------
   -- Extensions handling --
   -------------------------

   function gpr_register_extension (Name : chars_ptr)
      return unsigned
   is
   begin
      Clear_Last_Exception;

      return unsigned (Register_Extension (Value (Name)));
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return 0;
   end;

   function gpr_node_extension
     (Node   : gpr_base_node;
      Ext_Id : unsigned;
      Dtor   : gpr_node_extension_destructor)
      return System.Address
   is
   begin
      Clear_Last_Exception;

      declare
         N  : constant GPR_Node := Unwrap (Node);
         ID : constant Extension_ID := Extension_Id (Ext_Id);
         D  : constant Extension_Destructor := Convert (Dtor);
      begin
         return Get_Extension (N, ID, D).all'Address;
      end;
   exception
      when Exc : others =>
         Set_Last_Exception (Exc);
         return System.Null_Address;
   end;

   ----------
   -- Wrap --
   ----------

   function Wrap (S : Unbounded_Wide_Wide_String) return gpr_text is
      Chars  : Big_Wide_Wide_String_Access;
      Length : Natural;
   begin
      Get_Wide_Wide_String (S, Chars, Length);
      return (Chars.all'Address, size_t (Length), 0);
   end Wrap;

   ------------------------
   -- Set_Last_Exception --
   ------------------------

   procedure Set_Last_Exception
     (Exc      : Exception_Occurrence;
      Is_Fatal : Boolean := True)
   is
   begin
      --  If it's the first time, allocate room for the exception information

      if Last_Exception = null then
         Last_Exception := new gpr_exception;

      --  If it is not the first time, free memory allocated for the last
      --  exception.

      elsif Last_Exception.Information /= Null_Ptr then
         Free (Last_Exception.Information);
      end if;

      Last_Exception.Is_Fatal := (if Is_Fatal then 1 else 0);
      Last_Exception.Information := New_String (Exception_Information (Exc));
   end Set_Last_Exception;

   --------------------------
   -- Clear_Last_Exception --
   --------------------------

   procedure Clear_Last_Exception is
   begin
      if Last_Exception /= null then
         Free (Last_Exception.Information);
      end if;
   end Clear_Last_Exception;

   function gpr_get_last_exception return gpr_exception_Ptr
   is
   begin
      if Last_Exception = null
         or else Last_Exception.Information = Null_Ptr
      then
         return null;
      else
         return Last_Exception;
      end if;
   end;

   function gpr_token_kind_name (Kind : int) return chars_ptr
   is
      K : Token_Kind;
   begin
      begin
         K := Token_Kind'Enum_Val (Kind);
      exception
         when Exc : Constraint_Error =>
            Set_Last_Exception (Exc);
            return Null_Ptr;
      end;

      return New_String (Token_Kind_Name (K));
   end;

   procedure gpr_token_next
     (Token      : gpr_token_Ptr;
      Next_Token : gpr_token_Ptr)
   is
      T  : constant Token_Type := Unwrap (Token.all);
      NT : constant Token_Type := Next (T);
   begin
      Next_Token.all := Wrap (NT);
   end;

   procedure gpr_token_previous
     (Token          : gpr_token_Ptr;
      Previous_Token : gpr_token_Ptr)
   is
      T  : constant Token_Type := Unwrap (Token.all);
      PT : constant Token_Type := Previous (T);
   begin
      Previous_Token.all := Wrap (PT);
   end;

   ------------
   -- Unwrap --
   ------------

   function Unwrap
     (Unit : Analysis_Unit_Interface;
      Text : gpr_text)
      return Symbol_Type
   is
      T : Text_Type (1 .. Natural (Text.Length));
      for T'Address use Text.Chars;
   begin
     return Find (Unit.Token_Data.Symbols, T, False);
   end Unwrap;

   ----------------
   -- Wrap_Alloc --
   ----------------

   function Wrap_Alloc (S : Text_Type) return gpr_text
   is
      T : Text_Access := new Text_Type'(S);
   begin
      return gpr_text'(T.all'Address, T.all'Length, Is_Allocated => 1);
   end Wrap_Alloc;

   procedure gpr_destroy_text (T : gpr_text_Ptr) is
      use System;
   begin
      if T.Is_Allocated /= 0 and then T.Chars /= System.Null_Address then
         declare
            TT : Text_Type (1 .. Natural (T.Length));
            for TT'Address use T.Chars;
            TA : Text_Access := TT'Unrestricted_Access;
         begin
            Free (TA);
         end;
         T.Chars := System.Null_Address;
      end if;
   end;

end GPR_Parser.Analysis.C;
