------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                       Copyright (C) 2008, AdaCore                        --
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

with Ada.Unchecked_Conversion;

with GNAT.MD5;

with AWS.Translator;

package body AWS.Jabber.Digest_Md5 is

   use Ada;

   function Response
     (Username, Realm, Password, Host, Nonce, Cnonce : in String)
      return String;
   --  Generate the response directive

   function Make_URP_Hash
     (Username, Realm, Password : in String) return String;
   --  Compute the 16 octect md5 hash of username:realm:password

   ----------------------
   -- Decode_Challenge --
   ----------------------

   function Decode_Challenge
     (Encoded_Challenge : in String) return Challenge
   is
      Decoded_Challenge : Challenge;

      procedure Parse_Key_Value (S : in String);
      --  Parse a key=value string and fill challenge

      ---------------------
      -- Parse_Key_Value --
      ---------------------

      procedure Parse_Key_Value (S : in String) is
      begin
         for K in S'Range loop
            if S (K) = '=' then
               if S (S'First .. K - 1) = "nonce" then
                  if S (K + 1) = '"' then
                     Decoded_Challenge.Nonce :=
                       To_Unbounded_String (S (K + 2 .. S'Last - 1));
                  else
                     Decoded_Challenge.Nonce :=
                       To_Unbounded_String (S (K + 1 .. S'Last));
                  end if;

               elsif S (S'First .. K - 1) = "realm" then
                  if S (K + 1) = '"' then
                     Decoded_Challenge.Realm :=
                       To_Unbounded_String (S (K + 2 .. S'Last - 1));
                  else
                     Decoded_Challenge.Realm :=
                       To_Unbounded_String (S (K + 1 .. S'Last));
                  end if;
               end if;
            end if;
         end loop;
      end Parse_Key_Value;

      Message : constant String := AWS.Translator.To_String
        (AWS.Translator.Base64_Decode (Encoded_Challenge));
      Index : Natural := Message'First;

   begin
      --  Get a key=value message separated with ','
      for K in Message'Range loop
         if Message (K) = ',' then
            Parse_Key_Value (Message (Index .. K - 1));
            Index := K + 1;
         end if;
      end loop;

      return Decoded_Challenge;
   end Decode_Challenge;

      -------------------
   -- Make_URP_Hash --
   -------------------

   function Make_URP_Hash
     (Username, Realm, Password : in String) return String
   is
      type Byte is mod 2 ** 8;
      type Byte_Array is array (Long_Integer range <>) of Byte;
      pragma Pack (Byte_Array);

      subtype Fingerprint   is Byte_Array (1 .. 16);  --  128 bits
      subtype Digest_String is String     (1 .. 32);  --  Fingerprint in hex

      subtype Fingerprint_String is String (1 .. 16);
      function To_String is new Unchecked_Conversion
        (Source => Fingerprint,
         Target => Fingerprint_String);

      function Digest_From_Text (S : in Digest_String) return Fingerprint;

      ----------------------
      -- Digest_From_Text --
      ----------------------

      function Digest_From_Text (S : in Digest_String) return Fingerprint is
         type Word is mod 2 ** 32;

         function Shift_Left  (Value : Word; Amount : Natural) return Word;
         pragma Import (Intrinsic, Shift_Left);

         Digest : Fingerprint;
         Val   : Word;
         Ch    : Character;

      begin

         for I in Digest'Range loop

            Ch := S (2 * Integer (I - 1) + 1);
            case Ch is
               when '0' .. '9' => Val
                  := Character'Pos (Ch) - Character'Pos ('0');
               when 'a' .. 'f' => Val
                  := Character'Pos (Ch) - Character'Pos ('a') + 10;
               when 'A' .. 'F' => Val
                  := Character'Pos (Ch) - Character'Pos ('A') + 10;
               when others     => raise Program_Error;
            end case;

            Val := Shift_Left (Val, 4);

            Ch := S (2 * Integer (I));
            case Ch is
               when '0' .. '9' => Val
                  := Val + (Character'Pos (Ch) - Character'Pos ('0'));
               when 'a' .. 'f' => Val
                  := Val + (Character'Pos (Ch) - Character'Pos ('a') + 10);
               when 'A' .. 'F' => Val
                  := Val + (Character'Pos (Ch) - Character'Pos ('A') + 10);
               when others     => raise Program_Error;
            end case;

            Digest (I) := Byte (Val);

         end loop;

         return Digest;
      end Digest_From_Text;

      URP : constant String := Username & ':' & Realm & ':' & Password;
      URP_Digest : constant Digest_String := GNAT.MD5.Digest (URP);
   begin
      return To_String (Digest_From_Text (URP_Digest));
   end Make_URP_Hash;

   ---------------------
   -- Reply_Challenge --
   ---------------------

   function Reply_Challenge
     (Username, Realm, Password, Host, Nonce : in String) return String is
      --  Return a base64 encoded form of
      --  username="Username",realm="Realm",nonce="Nonce",
      --  cnone="A_Client_Generated_Nonce",nc=0000001,qop=auth,
      --  digest-uri="xmpp/Hostname",response=A_Computed_challenge_response,
      --  charset=utf-8

      --  ??? Note that authzid is not used.

      CNonce  : constant String := "0092811472856696084237038";
      --  ??? CNonce should be generated

      Clear_Response : constant String :=
        "realm=" & '"' & Realm & '"' & ','
        & "username=" & '"' & Username & '"' & ','
        & "cnonce=" & '"' & CNonce & '"' & ','
        & "nonce=" & '"' & Nonce & '"' & ','
        & "nc=" & "00000001" & ','
        & "qop=" & "auth" & ','
        & "digest-uri=" & '"' & "xmpp/" & Host & '"' & ','
        & "response=" & Digest_Md5.Response
        (Username, Realm, Password, Host, Nonce, CNonce);
   begin
      return AWS.Translator.Base64_Encode (Clear_Response);
   end Reply_Challenge;

   --------------
   -- Response --
   --------------

   function Response
     (Username, Realm, Password, Host, Nonce, Cnonce : in String)
      return String is
      --  The value of the response directive is computed as follows:
      --   * Create a 16 octet md5 hash of a string
      --     of the form "username:realm:password".
      --     Call it string URP
      --   * create a string of the form "URP:nonce:cnonce:authzid".
      --     Call this string A1.
      --   * Create a string of the form "AUTHENTICATE:digest-uri".
      --     Call this string A2.
      --   * Compute the 32 hex digit MD5 hash of A1. Call the result HA1.
      --   * Compute the 32 hex digit MD5 hash of A2. Call the result HA2.
      --   * Then compute the 32 hex digit MD5 hash
      --     of "HA1:nonce:nc:cnonce:qop:HA2"
      URP : constant String :=
              Digest_Md5.Make_URP_Hash
                (Username, Realm, Password);
      A1  : constant String := URP & ":" & Nonce & ':' & Cnonce;
      A2  : constant String := "AUTHENTICATE:xmpp/" & Host;
      HA1 : constant GNAT.MD5.Message_Digest := GNAT.MD5.Digest (A1);
      HA2 : constant GNAT.MD5.Message_Digest := GNAT.MD5.Digest (A2);
   begin
      --  Compute the 32 hex digit MD5 hash of KD
      return GNAT.MD5.Digest
        (HA1 & ":" & Nonce & ":00000001:" & Cnonce & ":auth:" & HA2);
   end Response;

end AWS.Jabber.Digest_Md5;