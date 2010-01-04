------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2000-2009, AdaCore                     --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

with Ada.Streams;
with Ada.Strings.Fixed;

with AWS.Containers.Tables.Set;
with AWS.Config;
with AWS.Translator;
with AWS.URL;

package body AWS.Parameters.Set is

   use AWS.Containers;

   ---------
   -- Add --
   ---------

   procedure Add
     (Parameter_List : in out List;
      Name, Value    : String;
      Decode         : Boolean := True) is
   begin
      if Parameter_List.Parameters = Null_Unbounded_String then
         Append (Parameter_List.Parameters, "?");
      else
         Append (Parameter_List.Parameters, "&");
      end if;
      Append (Parameter_List.Parameters, Name & "=" & Value);

      if Decode then
         --  This is default behavior
         Tables.Set.Add
           (Tables.Table_Type (Parameter_List),
            URL.Decode (Name),
            URL.Decode (Value));

      else
         Tables.Set.Add (Tables.Table_Type (Parameter_List), Name, Value);
      end if;
   end Add;

   ---------
   -- Add --
   ---------

   procedure Add (Parameter_List : in out List; Parameters : String) is
      use Ada.Strings;

      P : String renames Parameters;
      C : Positive := P'First;
      I : Natural;
      S : Positive := P'First;
      E : Natural;
   begin
      --  Skip leading question mark if present

      if P /= "" and then P (C) = '?' then
         C := Positive'Succ (C);
         S := Positive'Succ (S);
      end if;

      loop
         I := Fixed.Index (P (C .. P'Last), "=");

         exit when I = 0;

         S := I + 1;

         E := Fixed.Index (P (S .. P'Last), "&");

         if E = 0 then
            --  last parameter

            Add (Parameter_List, P (C .. I - 1), P (S .. P'Last));
            exit;

         else
            Add (Parameter_List, P (C .. I - 1), P (S .. E - 1));
            C := E + 1;
         end if;
      end loop;
   end Add;

   procedure Add
     (Parameter_List : in out List;
      Parameters     : in out AWS.Containers.Memory_Streams.Stream_Type)
   is
      use Ada.Streams;
      use AWS.Containers.Memory_Streams;
      use AWS.Translator;

      Amp   : constant Stream_Element := Character'Pos ('&');
      Buffer : Stream_Element_Array
                 (1 .. Stream_Element_Offset'Min
                         (Stream_Element_Offset
                            (AWS.Config.Input_Line_Size_Limit),
                          Size (Parameters)));
      First : Stream_Element_Offset := Buffer'First;
      Last  : Stream_Element_Offset;
      Found : Boolean;
      WNF   : Boolean := False;
      --  Was not found. This flag need to detect more than once 'not found'
      --  cases. If length of parameter name and value no more than
      --  AWS.Config.Input_Line_Size_Limit, 'not Found' case could happen only
      --  at the end of parameters line. In case of twice 'not Found' cases we
      --  raise Too_Long_Parameter.
   begin
      if Buffer'Length = 0 then
         return;
      end if;

      Reset (Parameters);

      loop
         Read (Parameters, Buffer (First .. Buffer'Last), Last);

         Found := False;

         Find_Last_Amp : for J in reverse First .. Last loop
            if Buffer (J) = Amp then
               Found := True;
               Add (Parameter_List, To_String (Buffer (1 .. J - 1)));
               Buffer (1 .. Last - J) := Buffer (J + 1 .. Last);
               First := Last - J + 1;
               exit Find_Last_Amp;
            end if;
         end loop Find_Last_Amp;

         if not Found then
            if WNF and then First <= Last then
               raise Too_Long_Parameter with
                 "Too long one of HTTP parameters: "
                 & Slice
                     (Parameter_List.Parameters,
                      1, Integer'Min (Length (Parameter_List.Parameters), 64));
            end if;

            WNF := True;

            Add (Parameter_List, To_String (Buffer (1 .. Last)));
            First := 1;
         end if;

         exit when Last < Buffer'Last;
      end loop;
   end Add;

   --------------------
   -- Case_Sensitive --
   --------------------

   procedure Case_Sensitive
     (Parameter_List : in out List;
      Mode           : Boolean) is
   begin
      Tables.Set.Case_Sensitive (Tables.Table_Type (Parameter_List), Mode);
   end Case_Sensitive;

   -----------
   -- Reset --
   -----------

   procedure Reset (Parameter_List : in out List) is
   begin
      Tables.Set.Reset (Tables.Table_Type (Parameter_List));
      Parameter_List.Parameters := Null_Unbounded_String;
   end Reset;

   ------------
   -- Update --
   ------------

   procedure Update
     (Parameter_List : in out List;
      Name, Value    : String;
      Decode         : Boolean := True)
   is
      First : constant Natural :=
                Index (Parameter_List.Parameters, Name & "=");
      Last  : Natural;
   begin
      if First = 0 then
         --  This Name is not already present, add it
         if Parameter_List.Parameters = Null_Unbounded_String then
            Append (Parameter_List.Parameters, "?");
         else
            Append (Parameter_List.Parameters, "&");
         end if;

         Append (Parameter_List.Parameters, Name & "=" & Value);

      else
         --  Replace the existing value
         Last := Index (Parameter_List.Parameters, "&", From => First);

         if Last = 0 then
            --  This is the last argument
            Last := Length (Parameter_List.Parameters);
         else
            Last := Last - 1;
         end if;

         Replace_Slice
           (Parameter_List.Parameters,
            Low  => First + Name'Length + 1,
            High => Last,
            By   => Value);
      end if;

      if Decode then
         --  This is default behavior
         Tables.Set.Update
           (Tables.Table_Type (Parameter_List),
            URL.Decode (Name),
            URL.Decode (Value));

      else
         Tables.Set.Update (Tables.Table_Type (Parameter_List), Name, Value);
      end if;
   end Update;

end AWS.Parameters.Set;