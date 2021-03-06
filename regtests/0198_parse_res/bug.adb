------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2009-2012, AdaCore                     --
--                                                                          --
--  This is free software;  you can redistribute it  and/or modify it       --
--  under terms of the  GNU General Public License as published  by the     --
--  Free Software  Foundation;  either version 3,  or (at your option) any  --
--  later version.  This software is distributed in the hope  that it will  --
--  be useful, but WITHOUT ANY WARRANTY;  without even the implied warranty --
--  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU     --
--  General Public License for  more details.                               --
--                                                                          --
--  You should have  received  a copy of the GNU General  Public  License   --
--  distributed  with  this  software;   see  file COPYING3.  If not, go    --
--  to http://www.gnu.org/licenses for a complete copy of the license.      --
------------------------------------------------------------------------------

with Ada.Text_IO;            use Ada.Text_IO;

with AWS.Resources.Embedded;
with AWS.Utils;
with AWS.Templates;

with Res;

procedure Bug is
   use AWS;

   Name : constant String := "text.txt";
   Set  : Templates.Translate_Set;
begin
   Put_Line ("On disk : " & Aws.Utils.Is_Regular_File (Name)'Img);
   Put_Line ("Embedded: " & Aws.Resources.Embedded.Exist (Name)'Img);

   Templates.Insert (Set, Templates.Assoc ("NAME", "text.txt"));
   Put_Line (Templates.Parse (Name, Set));
end Bug;
