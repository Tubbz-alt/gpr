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

with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;

with GNAT.Directory_Operations;
with GNAT.OS_Lib;
with GNAT.Regpat;

with DOM.Core.Nodes;
with DOM.Core.Documents;
with Input_Sources.File;
with Input_Sources.Strings;
with Schema.Dom_Readers;
with Sax.Readers;
with Unicode.CES.Utf8;

with GNATCOLL.Traces;

with GPR2.Containers;
with GPR2.Message;
with GPR2.Source_Reference;

pragma Warnings (Off);
with System.OS_Constants;
pragma Warnings (On);

package body GPR2.KB.Parsing is

   function Default_Content return GPR2.Containers.Name_Value_Map
     with Post => not Default_Content'Result.Is_Empty;
   --  Returns default contents of the knowledge base embedded
   --  into the library. Result maps name of the file used for embedding
   --  to its contents.
   --  Result maps base names of files used to create the embedded knowledge
   --  base to their contents.

   function Get_Attribute
     (N         : DOM.Core.Node;
      Attribute : Value_Not_Empty;
      Default   : Value_Type) return Value_Type
     with Pre  => DOM.Core."/=" (N, null),
          Post => Get_Attribute'Result'Length > 0
                  or else Get_Attribute'Result = Default;
   --  Returns the value of an attribute, or Default if the attribute does not
   --  exist.

   function Node_Value_As_String (N : DOM.Core.Node) return String
     with Pre  => DOM.Core."/=" (N, null);
   --  Returns the value of the node, concatenating all Text children

   procedure Parse_Knowledge_Base
     (Base      : in out Object;
      Root_Node : DOM.Core.Node;
      Flags     : Parsing_Flags;
      From_File : Value_Not_Empty)
     with Pre => Base.Is_Defined and then DOM.Core."/=" (Root_Node, null);
   --  Parses a single top-level KB node. From_File used for diagnostics

   Embed_Pseudo_Dir : constant String :=
                        "embedded_kb" & Directory_Operations.Dir_Separator;
   --  Used for reporting potential errors in the embeded base

   Main_Trace : constant GNATCOLL.Traces.Trace_Handle :=
                  GNATCOLL.Traces.Create
                    ("KNOWLEDGE_BASE.PARSING_TRACE",
                     GNATCOLL.Traces.From_Config);

   Invalid_KB : exception;
   --  Raised when an error occurred while parsing the knowledge base

   Ignore_Compiler : exception;
   --  Raised when the compiler should be ignored

   ---------
   -- Add --
   ---------

   procedure Add
     (Self    : in out Object;
      Flags   : Parsing_Flags;
      Content : Value_Not_Empty)
   is
      use DOM.Core, DOM.Core.Nodes;
      use Input_Sources.Strings;
      use Schema.Dom_Readers;
      use Sax.Readers;

      use GNATCOLL.Traces;

      String_Argument : constant String := "string_argument";
      Reader          : Schema.Dom_Readers.Tree_Reader;
      Input           : String_Input;

   begin
      Trace (Main_Trace, "Parsing string");
      Reader.Set_Feature (Schema_Validation_Feature, Flags (Validation));
      Reader.Set_Feature (Validation_Feature, False);  --  Do not use DTD

      Open (Unicode.CES.Byte_Sequence (String (Content)),
            Unicode.CES.Utf8.Utf8_Encoding,
            Input);
      Parse (Reader, Input);
      Close (Input);

      Parse_Knowledge_Base
        (Self,
         DOM.Core.Documents.Get_Element (Get_Tree (Reader)),
         Flags,
         Embed_Pseudo_Dir & String_Argument);

      declare
         Doc : Document := Get_Tree (Reader);
      begin
         Free (Doc);
      end;

      Free (Reader);
   end Add;

   ---------------------
   -- Default_Content --
   ---------------------

   function Default_Content return GPR2.Containers.Name_Value_Map is
      use Ada.Strings.Fixed;
      use GPR2.Containers;

      KB_Start    : constant Character
                      with Import     => True,
                           Convention => C,
                           Link_Name  => "_binary_config_kb_start";
      KB_Length   : constant Integer
                      with Import     => True,
                           Convention => C,
                           Link_Name  => "_binary_config_kb_size";

      Result      : Name_Value_Map;
      KB          : String (1 .. KB_Length) with Address => KB_Start'Address;
      Idx1        : Integer;
      Idx2        : Integer;
      Idx3        : Integer;
      File_Length : Positive;

   begin
      --  Embedded knowledge base is expected to be a string representing all
      --  individual files forming the knowledge base in the following format:
      --
      --  <file_name>:<length>:<content>{<file_name>:<length>:<content>}
      --
      --  where <length> indicates the length of the <content> field and
      --  <file_name> is the base name of the file included in the base.

      Idx1 := KB'First;

      while Idx1 in KB'First .. KB'Last - 2 loop
         Idx2 := Index (KB, ":", Idx1);

         if Idx2 <= Idx1 or else Idx2 = KB'Last then
            raise Invalid_KB with "malformed default knowledge base at"
              & Idx1'Img;
         end if;

         Idx3 := Index (KB, ":", Idx2 + 1);

         if Idx3 <= Idx2 then
            raise Invalid_KB with "malformed default knowledge base at"
              & Idx2'Img;
         end if;

         File_Length := Positive'Value (KB (Idx2 + 1 .. Idx3 - 1));

         if Idx3 + File_Length > KB'Last then
            raise Invalid_KB with "malformed default knowledge base at"
              & Idx3'Img;
         end if;

         Result.Include
           (Name_Type (KB (Idx1 .. Idx2 - 1)),
            Value_Type (KB (Idx3 + 1 .. Idx3  + File_Length)));

         Idx1 := Idx3 + File_Length + 1;
      end loop;

      return Result;
   end Default_Content;

   -------------------
   -- Get_Attribute --
   -------------------

   function Get_Attribute
     (N         : DOM.Core.Node;
      Attribute : Value_Not_Empty;
      Default   : Value_Type) return Value_Type
   is
      use DOM.Core;
      use DOM.Core.Nodes;

      Attr : constant Node := Get_Named_Item (Attributes (N), Attribute);
   begin
      if Attr = null then
         return Default;
      else
         return Node_Value (Attr);
      end if;
   end Get_Attribute;

   --------------------------
   -- Node_Value_As_String --
   --------------------------

   function Node_Value_As_String (N : DOM.Core.Node) return String is
      use DOM.Core;
      use DOM.Core.Nodes;

      Result : Unbounded_String;
      Child  : Node := First_Child (N);
   begin
      while Child /= null loop
         exit when Node_Type (Child) = Element_Node;
         Append (Result, Node_Value (Child));
         Child := Next_Sibling (Child);
      end loop;

      return To_String (Result);
   end Node_Value_As_String;

   ----------------------------------
   -- Parse_Default_Knowledge_Base --
   ----------------------------------

   function Parse_Default_Knowledge_Base
     (Flags : Parsing_Flags) return Object
   is
      use GNAT.Directory_Operations;
      use GNATCOLL.Traces;
      use DOM.Core;
      use DOM.Core.Nodes;
      use Input_Sources.Strings;
      use Schema.Dom_Readers;
      use Sax.Readers;

      use GPR2.Containers.Name_Value_Map_Package;

      KB_Content : GPR2.Containers.Name_Value_Map;
      Result     : Object;

      type Resolving_Reader is new Schema.Dom_Readers.Tree_Reader with record
         Current_Source : Unbounded_String;
      end record;

      overriding function Resolve_Entity
        (Handler   : Resolving_Reader;
         Public_Id : Unicode.CES.Byte_Sequence;
         System_Id : Unicode.CES.Byte_Sequence)
         return Input_Sources.Input_Source_Access;
      --  Resolves entities from knowledge base

      --------------------
      -- Resolve_Entity --
      --------------------

      overriding function Resolve_Entity
        (Handler   : Resolving_Reader;
         Public_Id : Unicode.CES.Byte_Sequence;
         System_Id : Unicode.CES.Byte_Sequence)
         return Input_Sources.Input_Source_Access
      is
         Pub_Id : constant Optional_Name_Type :=
                    Optional_Name_Type (Public_Id);
         Sys_Id : constant Optional_Name_Type :=
                    Optional_Name_Type (System_Id);
         Input  : constant String_Input_Access :=
                    (if Pub_Id /= "" or else Sys_Id /= "" then new String_Input
                     else null);
      begin
         Trace (Main_Trace, "Public_Id=""" & Public_Id & """");
         Trace (Main_Trace, "System_Id=""" & System_Id & """");

         if Pub_Id /= "" and then KB_Content.Contains (Pub_Id) then
            Open
              (KB_Content.Element (Pub_Id),
               Unicode.CES.Utf8.Utf8_Encoding,
               Input.all);

         elsif Sys_Id /= "" and then KB_Content.Contains (Sys_Id) then
            Open
              (KB_Content.Element (Sys_Id),
               Unicode.CES.Utf8.Utf8_Encoding,
               Input.all);
         else
            Result.Messages.Append
              (Message.Create
                 (Message.Error,
                  "entity not found for Public_Id="""
                  & Public_Id
                  & """, System_Id="""
                  & System_Id
                  & """",
                  Source_Reference.Create
                    (Embed_Pseudo_Dir & To_String (Handler.Current_Source),
                     0, 0)));
         end if;

         return Input_Sources.Input_Source_Access (Input);
      end Resolve_Entity;

      Reader : Resolving_Reader;
      Input  : String_Input;
      Cur    : Containers.Name_Value_Map_Package.Cursor;
   begin
      Result.Initialized := True;
      KB_Content := Default_Content;

      Cur := KB_Content.First;

      while Cur /= No_Element loop
         if File_Extension (String (Key (Cur))) = ".xml" then
            Trace (Main_Trace, "Parsing embedded file " & String (Key (Cur)));
            Reader.Current_Source := To_Unbounded_String (String (Key (Cur)));
            Reader.Set_Feature (Schema_Validation_Feature, Flags (Validation));
            Reader.Set_Feature (Validation_Feature, False);  --  Do not use DTD

            Open
              (Containers.Name_Value_Map_Package.Element (Cur),
               Unicode.CES.Utf8.Utf8_Encoding,
               Input);
            Parse (Reader, Input);
            Close (Input);

            Parse_Knowledge_Base
              (Result,
               DOM.Core.Documents.Get_Element (Get_Tree (Reader)),
               Flags,
               Embed_Pseudo_Dir & String (Key (Cur)));

            declare
               Doc : Document := Get_Tree (Reader);
            begin
               Free (Doc);
            end;

            Free (Reader);
         end if;

         Next (Cur);
      end loop;

      return Result;
   end Parse_Default_Knowledge_Base;

   --------------------------
   -- Parse_Knowledge_Base --
   --------------------------

   procedure Parse_Knowledge_Base
     (Self     : in out Object;
      Location : GPR2.Path_Name.Object;
      Flags    : Parsing_Flags)
   is
      use GPR2.Path_Name;
      use Ada.Directories;

      procedure Parse_Single_File (File : GPR2.Path_Name.Object);
      --  Parses a single .xml file containing KB chunks

      -----------------------
      -- Parse_Single_File --
      -----------------------

      procedure Parse_Single_File (File : GPR2.Path_Name.Object) is
         use GNATCOLL.Traces;
         use DOM.Core, DOM.Core.Nodes;
         use Input_Sources.File;
         use Schema.Dom_Readers;
         use Sax.Readers;

         Reader : Schema.Dom_Readers.Tree_Reader;
         Input  : File_Input;
      begin
         Trace (Main_Trace, "Parsing file " & String (File.Value));
         Reader.Set_Feature (Schema_Validation_Feature, Flags (Validation));
         Reader.Set_Feature (Validation_Feature, False);  --  Do not use DTD

         Open (String (File.Value), Input);
         Parse (Reader, Input);
         Close (Input);

         Parse_Knowledge_Base
           (Self,
            DOM.Core.Documents.Get_Element (Get_Tree (Reader)),
            Flags, File.Value);

         declare
            Doc : Document := Get_Tree (Reader);
         begin
            Free (Doc);
         end;

         Free (Reader);
      end Parse_Single_File;

      Search : Search_Type;
      File   : Directory_Entry_Type;

   begin
      if Location.Is_Directory then
         Start_Search
           (Search,
            Directory => String (Location.Value),
            Pattern   => "*.xml",
            Filter    => (Ordinary_File => True, others => False));

         while More_Entries (Search) loop
            Get_Next_Entry (Search, File);
            Parse_Single_File
              (Create_File
                 (Filename_Type (Ada.Directories.Full_Name ((File)))));
         end loop;

         End_Search (Search);

      else
         Parse_Single_File (Location);
      end if;
   end Parse_Knowledge_Base;

   --------------------------
   -- Parse_Knowledge_Base --
   --------------------------

   procedure Parse_Knowledge_Base
     (Base      : in out Object;
      Root_Node : DOM.Core.Node;
      Flags     : Parsing_Flags;
      From_File : Value_Not_Empty)
   is
      use DOM.Core;
      use DOM.Core.Nodes;

      Error_Sloc : constant Source_Reference.Object :=
                     Source_Reference.Object
                       (Source_Reference.Create (From_File, 0, 0));

      procedure Parse_Compiler_Description
        (Base        : in out Object;
         Description : DOM.Core.Node);
      --  Parses a compiler description described by N. Appends the result to
      --  Base.Compilers or Base.No_Compilers.

      procedure Parse_Configuration
        (Append_To   : in out Configuration_Lists.List;
         Description : DOM.Core.Node);
      --  Parses a configuration node

      procedure Parse_Targets_Set
        (Append_To   : in out Targets_Set_Vectors.Vector;
         Description : DOM.Core.Node);
      --  Parses a targets set node

      procedure Parse_Fallback_Targets_Set
        (Append_To   : in out Fallback_Targets_Set_Vectors.Vector;
         Description : DOM.Core.Node);
      --  Parses a fallback_targets set node

      --------------------------------
      -- Parse_Compiler_Description --
      --------------------------------

      procedure Parse_Compiler_Description
        (Base        : in out Object;
         Description : DOM.Core.Node)
      is
         use Ada.Characters.Handling;
         use GNAT.Regpat;
         use External_Value_Lists;
         use Pattern_Matcher_Holders;

         procedure Parse_External_Value
           (Value    : out External_Value;
            External : Node);
         --  Parses an XML node that describes an external value

         function Ends_With (Str, Suffix : String) return Boolean;
         --  Whether the string ends with Suffix. Always True if Suffix
         --  is an empty string.

         ---------------
         -- Ends_With --
         ---------------

         function Ends_With (Str, Suffix : String) return Boolean is
         begin
            return Suffix = ""
              or else
                (Str'Length >= Suffix'Length
                 and then Str
                   (Str'Last - Suffix'Length + 1 .. Str'Last) = Suffix);
         end Ends_With;

         --------------------------
         -- Parse_External_Value --
         --------------------------

         procedure Parse_External_Value
           (Value    : out External_Value;
            External : Node)
         is
            Static_Value  : constant String := Node_Value_As_String (External);
            Tmp           : Node := First_Child (External);
            External_Node : External_Value_Node;
            Is_Done       : Boolean := True;
            Has_Static    : Boolean := False;

            use External_Value_Nodes;
         begin
            for S in Static_Value'Range loop
               if Static_Value (S) not in ' ' | ASCII.LF then
                  Has_Static := True;
                  exit;
               end if;
            end loop;

            --  Constant value is not within a nested node

            if Has_Static then
               External_Node :=
                 (Typ   => Value_Constant,
                  Value => To_Unbounded_String (Static_Value));
               Append (Value.EV, External_Node);
               Is_Done := False;
            end if;

            while Tmp /= null loop
               if Node_Type (Tmp) /= Element_Node then
                  null;

               elsif Node_Name (Tmp) = "external" then
                  if not Is_Done then
                     Append (Value.EV, (Typ => Value_Done));
                  end if;

                  External_Node :=
                    (Typ     => Value_Shell,
                     Command => To_Unbounded_String
                       (Node_Value_As_String (Tmp)));
                  Append (Value.EV, External_Node);
                  Is_Done := False;

               elsif Node_Name (Tmp) = "directory" then
                  declare
                     C        : constant String :=
                                  Get_Attribute (Tmp, "contents", "");
                     Contents : Pattern_Matcher_Holder;
                  begin
                     if C /= "" then
                        Contents := To_Holder (Compile (C));
                     end if;

                     External_Node :=
                       (Typ             => Value_Directory,
                        Directory       => To_Unbounded_String
                                             (Node_Value_As_String (Tmp)),
                        Contents        => Contents,
                        Dir_If_Match    => Null_Unbounded_String,
                        Directory_Group => 0);
                  end;

                  begin
                     External_Node.Directory_Group :=
                       Integer'Value
                         (Get_Attribute (Tmp, "group", "0"));
                  exception
                     when Constraint_Error =>
                        External_Node.Directory_Group := -1;
                        External_Node.Dir_If_Match :=
                          To_Unbounded_String
                            (Get_Attribute (Tmp, "group", "0"));
                  end;

                  Append (Value.EV, External_Node);
                  Is_Done := True;

               elsif Node_Name (Tmp) = "getenv" then
                  if not Is_Done then
                     Append (Value.EV, (Typ => Value_Done));
                  end if;

                  declare
                     Name : constant String := Get_Attribute (Tmp, "name", "");
                  begin
                     if Ada.Environment_Variables.Exists (Name) then
                        External_Node :=
                          (Typ        => Value_Constant,
                           Value      => To_Unbounded_String
                             (Ada.Environment_Variables.Value (Name)));
                     else
                        Base.Messages.Append
                          (Message.Create
                             (Message.Warning,
                              "environment variable '"
                              & Name & "' is not defined",
                              Sloc => Error_Sloc));

                        External_Node :=
                          (Typ   => Value_Constant,
                           Value => Null_Unbounded_String);
                     end if;
                  end;

                  Append (Value.EV, External_Node);
                  Is_Done := False;

               elsif Node_Name (Tmp) = "filter" then
                  External_Node :=
                    (Typ        => Value_Filter,
                     Filter     => To_Unbounded_String
                       (Node_Value_As_String (Tmp)));
                  Append (Value.EV, External_Node);
                  Is_Done := True;

               elsif Node_Name (Tmp) = "must_match" then
                  External_Node :=
                    (Typ        => Value_Must_Match,
                     Must_Match => To_Unbounded_String
                       (Node_Value_As_String (Tmp)));
                  Append (Value.EV, External_Node);
                  Is_Done := True;

               elsif Node_Name (Tmp) = "grep" then
                  External_Node :=
                    (Typ       => Value_Grep,
                     Regexp_Re => To_Holder
                                    (Compile
                                      (Get_Attribute (Tmp, "regexp", ".*"),
                                       Multiple_Lines)),
                     Group     => Integer'Value
                                    (Get_Attribute (Tmp, "group", "0")));
                  Append (Value.EV, External_Node);

               elsif Node_Name (Tmp) = "nogrep" then
                  External_Node :=
                    (Typ       => Value_Nogrep,
                     Regexp_No => To_Holder
                                    (Compile
                                      (Get_Attribute (Tmp, "regexp", ".*"),
                                       Multiple_Lines)));
                  Append (Value.EV, External_Node);

               else
                  Base.Messages.Append
                    (Message.Create
                       (Message.Warning,
                        "invalid XML description for "
                        & Node_Name (External)
                        & ": invalid tag: " & Node_Name (Tmp),
                        Sloc => Error_Sloc));
                  Value := Null_External_Value;
               end if;

               Tmp := Next_Sibling (Tmp);
            end  loop;

            if not Is_Done then
               Append (Value.EV, (Typ => Value_Done));
            end if;

         exception
            when Constraint_Error =>
               Base.Messages.Append
                 (Message.Create
                    (Message.Warning,
                     "invalid group number for " & Node_Name (External),
                     Sloc => Error_Sloc));
               Value := Null_External_Value;
         end Parse_External_Value;

         Compiler    : Compiler_Description;
         N           : Node := First_Child (Description);
         Lang        : External_Value_Lists.List;
         C           : External_Value_Lists.Cursor;

         Exec_Suffix : OS_Lib.String_Access :=
                         OS_Lib.Get_Executable_Suffix;

      begin
         while N /= null loop
            if Node_Type (N) /= Element_Node then
               null;

            elsif Node_Name (N) = "executable" then
               declare
                  Prefix : constant String :=
                             Get_Attribute (N, "prefix", "@@");
                  Val    : constant String := Node_Value_As_String (N);
               begin
                  if Val = "" then
                     --  A special language that requires no executable. We do
                     --  not store it in the list of compilers, since these
                     --  should not be detected on the PATH anyway.

                     Compiler.Executable := Null_Unbounded_String;

                  else
                     Compiler.Executable := To_Unbounded_String (Val);

                     begin
                        Compiler.Prefix_Index := Integer'Value (Prefix);
                     exception
                        when Constraint_Error =>
                           Compiler.Prefix_Index := -1;
                     end;

                     if not Ends_With (Val, Exec_Suffix.all) then
                        Compiler.Executable_Re := To_Holder
                          (Compile ("^" & Val & Exec_Suffix.all & "$"));
                     else
                        Compiler.Executable_Re := To_Holder
                          (Compile ("^" & Val & "$"));
                     end if;

                     Base.Check_Executable_Regexp := True;
                  end if;

               exception
                  when Expression_Error =>
                     Base.Messages.Append
                       (Message.Create
                          (Message.Error,
                           "Invalid regular expression found in configuration:"
                           & Val,
                           Sloc => Error_Sloc));
                     Compiler.Executable_Re.Clear;
               end;

            elsif Node_Name (N) = "name" then
               Compiler.Name := To_Unbounded_String (Node_Value_As_String (N));

            elsif Node_Name (N) = "version" then
               Parse_External_Value
                 (Value    => Compiler.Version,
                  External => N);

            elsif Node_Name (N) = "variable" then
               declare
                  Name : constant String := Get_Attribute (N, "name", "@@");
               begin
                  Compiler.Variables.EV.Append
                    (External_Value_Node'
                      (Typ      => Value_Variable,
                       Var_Name => To_Unbounded_String (Name)));
                  Parse_External_Value
                    (Value    => Compiler.Variables,
                     External => N);
               end;

            elsif Node_Name (N) = "languages" then
               Parse_External_Value
                 (Value    => Compiler.Languages,
                  External => N);

            elsif Node_Name (N) = "runtimes" then
               declare
                  Defaults : constant String :=
                               Get_Attribute (N, "default", "");
               begin
                  if Defaults /= "" then
                     Get_Words (Defaults, "", ' ', ',',
                                Compiler.Default_Runtimes, False);
                  end if;

                  Parse_External_Value
                    (Value    => Compiler.Runtimes,
                     External => N);
               end;

            elsif Node_Name (N) = "target" then
               Parse_External_Value
                 (Value    => Compiler.Target,
                  External => N);

            else
               Base.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "Unknown XML tag in " & Node_Name (N),
                     Sloc => Error_Sloc));
               raise Invalid_KB;
            end if;

            N := Next_Sibling (N);
         end loop;

         if Compiler.Executable = Null_Unbounded_String then
            Get_External_Value
              (Attribute        => "languages",
               Value            => Compiler.Languages,
               Comp             => No_Compiler,
               Split_Into_Words => True,
               Calls_Cache      => Base.External_Calls_Cache,
               Messages         => Base.Messages,
               Processed_Value  => Lang);

            C := First (Lang);

            while Has_Element (C) loop
               Base.No_Compilers.Append
                 (Name_Type
                    (To_Lower
                       (To_String
                          (External_Value_Lists.Element (C).Value))));
               Next (C);
            end loop;

         elsif Compiler.Name /= Null_Unbounded_String then
            Base.Compilers.Include
              (Optional_Name_Type (To_String (Compiler.Name)), Compiler);

            --  Include the language name in the Languages_Known hashed map,
            --  if it is not already there.

            Get_External_Value
              (Attribute        => "languages",
               Value            => Compiler.Languages,
               Comp             => No_Compiler,
               Split_Into_Words => True,
               Calls_Cache      => Base.External_Calls_Cache,
               Messages         => Base.Messages,
               Processed_Value  => Lang);

            C := First (Lang);

            while Has_Element (C) loop
               declare
                  Lang_LC : Unbounded_String;
               begin
                  Lang_LC :=
                    To_Unbounded_String
                      (To_Lower
                         (To_String (External_Value_Lists.Element (C).Value)));
                  if not Base.Languages_Known.Contains (Lang_LC) then
                     Base.Languages_Known.Include (Lang_LC, Lang_LC);
                  end if;
               end;

               Next (C);
            end loop;
         end if;

         OS_Lib.Free (Exec_Suffix);
      end Parse_Compiler_Description;

      -------------------------
      -- Parse_Configuration --
      -------------------------

      procedure Parse_Configuration
        (Append_To   : in out Configuration_Lists.List;
         Description : DOM.Core.Node)
      is
         use Ada.Characters.Handling;
         use GNAT.Regpat;
         use Compilers_Filter_Lists;

         function Compile_And_Check
           (Name : String) return Pattern_Matcher_Holder;
         --  Compiles pattern and report illegal regexp if needed

         -----------------------
         -- Compile_And_Check --
         -----------------------

         function Compile_And_Check
           (Name : String) return Pattern_Matcher_Holder
         is
            use Pattern_Matcher_Holders;
         begin
            if Name = "" then
               return Empty_Holder;
            else
               return To_Holder
                 (Compile (Name, Regpat.Case_Insensitive));
            end if;
         exception
            when Expression_Error =>
               --  We do not want to invalidate the whole Knowledge
               --  Base because of a wrong regexp. Istead, report it
               --  and skip corresponding <configuration> node.
               Base.Messages.Append
                 (Message.Create
                    (Message.Warning,
                     "Invalid regexp '"
                     & Name & "'; corresponding configuration "
                     & "node skipped",
                     Sloc => Error_Sloc));
               raise;
         end Compile_And_Check;

         Config           : Configuration_Type;
         Chunk            : Unbounded_String;
         N                : Node := First_Child (Description);
         N2               : Node;
         Compilers        : Compilers_Filter;
         Ignore_Config    : Boolean := False;
         Negate           : Boolean;
         Filter           : Compiler_Filter;

         Default_Hostname : String renames System.OS_Constants.Target_Name;

      begin
         Config.Supported := True;

         while N /= null loop
            if Node_Type (N) /= Element_Node then
               null;

            elsif Node_Name (N) = "compilers" then
               Compilers := No_Compilers_Filter;
               N2 := First_Child (N);

               while N2 /= null loop
                  if Node_Type (N2) /= Element_Node then
                     null;

                  elsif Node_Name (N2) = "compiler" then
                     declare
                        Name    : constant String :=
                                    Get_Attribute (N2, "name", "");
                        Version : constant String :=
                                    Get_Attribute (N2, "version", "");
                        Runtime : constant String :=
                                    Get_Attribute (N2, "runtime", "");
                     begin
                        Filter := Compiler_Filter'
                          (Name        => To_Unbounded_String (Name),
                           Name_Re     => Compile_And_Check (Name),
                           Version     => To_Unbounded_String (Version),
                           Version_Re  => Compile_And_Check (Version),
                           Runtime     => To_Unbounded_String (Runtime),
                           Runtime_Re  => Compile_And_Check (Runtime),
                           Language_LC => To_Unbounded_String
                                            (To_Lower
                                               (Get_Attribute
                                                  (N2, "language", ""))));
                     end;

                     Compilers.Compiler.Append (Filter);

                  else
                     Base.Messages.Append
                       (Message.Create
                          (Message.Error,
                           "Unknown XML tag in " & Node_Name (N2),
                           Sloc => Error_Sloc));
                     raise Invalid_KB;
                  end if;

                  N2 := Next_Sibling (N2);
               end loop;

               Compilers.Negate :=
                 Boolean'Value (Get_Attribute (N, "negate", "False"));
               Config.Compilers_Filters.Append (Compilers);

            elsif Node_Name (N) = "targets" then
               if not Config.Targets_Filters.Is_Empty then
                  Base.Messages.Append
                    (Message.Create
                       (Message.Warning,
                        "Multiple <targets> filters specified for "
                        & "configuration node, filter ignored",
                        Sloc => Error_Sloc));

               else
                  N2 := First_Child (N);

                  while N2 /= null loop
                     if Node_Type (N2) /= Element_Node then
                        null;

                     elsif Node_Name (N2) = "target" then
                        declare
                           Double_Regexp : constant Double_String :=
                             (To_Unbounded_String
                                (Get_Attribute (N2, "name", "")),
                              To_Unbounded_String
                                (Get_Attribute (N2, "except", "")));
                        begin
                           Config.Targets_Filters.Append (Double_Regexp);
                        end;

                     else
                        Base.Messages.Append
                          (Message.Create
                             (Message.Error,
                              "Unknown XML tag in " & Node_Name (N2),
                           Sloc => Error_Sloc));
                        raise Invalid_KB;
                     end if;

                     N2 := Next_Sibling (N2);
                  end loop;

                  Config.Negate_Targets := Boolean'Value
                    (Get_Attribute (N, "negate", "False"));
               end if;

            elsif Node_Name (N) = "hosts" then
               --  Resolve this filter immediately. This saves memory, since we
               --  don't need to store it in memory if we know it won't apply.

               N2 := First_Child (N);
               Negate := Boolean'Value (Get_Attribute (N, "negate", "False"));

               Ignore_Config := not Negate;

               while N2 /= null loop
                  if Node_Type (N2) /= Element_Node then
                     null;

                  elsif Node_Name (N2) = "host" then
                     declare
                        Host_Same : constant Boolean :=
                                      Match
                                        (Get_Attribute
                                           (N2, "name", ""), Default_Hostname);
                        No_Except : constant Boolean :=
                                      Get_Attribute (N2, "except", "") = "";
                        Excepted  : constant Boolean :=
                                      Match
                                        (Get_Attribute (N2, "except", ""),
                                         Default_Hostname);
                     begin
                        if
                          Host_Same and then (No_Except or else not Excepted)
                        then
                           Ignore_Config := Negate;
                           exit;
                        end if;
                     end;

                  else
                     Base.Messages.Append
                       (Message.Create
                          (Message.Error,
                           "Unknown XML tag in " & Node_Name (N2),
                           Sloc => Error_Sloc));
                     raise Invalid_KB;
                  end if;

                  N2 := Next_Sibling (N2);
               end loop;

               exit when Ignore_Config;

            elsif Node_Name (N) = "config" then
               if Node_Value_As_String (N) = "" then
                  Config.Supported := False;
               else
                  Append (Chunk, Node_Value_As_String (N));
               end if;

            else
               Base.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "Unknown XML tag in " & Node_Name (N),
                     Sloc => Error_Sloc));
               raise Invalid_KB;
            end if;

            N := Next_Sibling (N);
         end loop;

         if not Ignore_Config then
            Config.Config := Chunk;
            Append_To.Append (Config);
         end if;
      exception
         when Expression_Error =>
            null;
            --  Proper warning message has been already emitted, so we just
            --  skip corresponding configuration node.
      end Parse_Configuration;

      --------------------------------
      -- Parse_Fallback_Targets_Set --
      --------------------------------

      procedure Parse_Fallback_Targets_Set
        (Append_To   : in out Fallback_Targets_Set_Vectors.Vector;
         Description : DOM.Core.Node)
      is
         Set : GPR2.Containers.Name_List;
         N   : Node := First_Child (Description);
      begin
         while N /= null loop
            if Node_Type (N) /= Element_Node then
               null;

            elsif Node_Name (N) = "target" then
               Set.Append (Optional_Name_Type (Node_Value_As_String (N)));

            else
               Base.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "Unknown XML tag in " & Node_Name (N),
                     Sloc => Error_Sloc));
               raise Invalid_KB;
            end if;

            N := Next_Sibling (N);
         end loop;

         if not Set.Is_Empty then
            Fallback_Targets_Set_Vectors.Append (Append_To, Set);
         end if;
      end Parse_Fallback_Targets_Set;

      -----------------------
      -- Parse_Targets_Set --
      -----------------------

      procedure Parse_Targets_Set
        (Append_To   : in out Targets_Set_Vectors.Vector;
         Description : DOM.Core.Node)
      is
         use GNAT.Regpat;

         Canon : constant String :=
                   Get_Attribute (Description, "canonical", "");
         Name  : Unbounded_String;
         Set   : Target_Lists.List;
         N     : Node := First_Child (Description);
      begin
         if Canon = "" then
            if Flags (Pedantic) then
               Base.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "No canonical target specified for target-set",
                     Sloc => Error_Sloc));
               raise Invalid_KB;
            end if;

         else
            Name := To_Unbounded_String (Canon);
         end if;

         while N /= null loop
            if Node_Type (N) /= Element_Node then
               null;

            elsif Node_Name (N) = "target" then
               declare
                  Val : constant String := Node_Value_As_String (N);
               begin
                  Target_Lists.Append (Set, Compile ("^" & Val & "$"));

                  if Name = Null_Unbounded_String then
                     --  When not in pedantic mode and working with
                     --  an old KB the first target in the target set
                     --  is taken as canonical target.
                     Name := To_Unbounded_String (Val);
                  end if;
               exception
                  when Expression_Error =>
                     Base.Messages.Append
                       (Message.Create
                          (Message.Error,
                           "Invalid regular expression " & Val
                           & " found in the target-set",
                           Sloc => Error_Sloc));
                        raise Invalid_KB;
               end;

            else
               Base.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "Unknown XML tag " & Node_Name (N),
                     Sloc => Error_Sloc));
               raise Invalid_KB;
            end if;

            N := Next_Sibling (N);
         end loop;

         if not Target_Lists.Is_Empty (Set) then
            Append_To.Append ((Name, Set), 1);
         end if;
      end Parse_Targets_Set;

      N : Node;

   begin
      if Node_Name (Root_Node) = "gprconfig" then
         N := First_Child (Root_Node);

         while N /= null loop
            if Node_Type (N) /= Element_Node then
               null;

            elsif Node_Name (N) = "compiler_description" then
               if Flags (Compiler_Info) then
                  Parse_Compiler_Description
                    (Base        => Base,
                     Description => N);
               end if;

            elsif Node_Name (N) = "configuration" then
               if Flags (Compiler_Info) then
                  Parse_Configuration
                    (Append_To   => Base.Configurations,
                     Description => N);
               end if;

            elsif Node_Name (N) = "targetset" then
               Parse_Targets_Set
                 (Append_To   => Base.Targets_Sets,
                  Description => N);

            elsif Node_Name (N) = "fallback_targets" then
               Parse_Fallback_Targets_Set
                 (Append_To   => Base.Fallback_Targets_Sets,
                  Description => N);

            else
               Base.Messages.Append
                 (Message.Create
                    (Message.Error,
                     "Unknown XML tag "
                     & Node_Name (N),
                     Sloc => Error_Sloc));
               raise Invalid_KB;
            end if;

            N := Next_Sibling (N);
         end loop;

      else
         Base.Messages.Append
           (Message.Create
              (Message.Error, "Invalid toplevel XML tag", Sloc => Error_Sloc));
      end if;
   exception
      when Invalid_KB =>
         --  Error messages have been added to the log, no point continuing
         --  parsing an inconsistent file.
         null;
   end Parse_Knowledge_Base;

end GPR2.KB.Parsing;
