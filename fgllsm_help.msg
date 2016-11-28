.1

Localized Strings Manager
-------------------------

This tool helps you to manage localized strings in a relational database.

You can 'Import' localized strings from .4gl, .per, .4tb, .4tm, .4sm and .4ad files into the database. After the import, you can edit and translate the texts in the database and finally create the '.str' string files with the 'Export' function. 

When the tool is started the first time, you must select the development language used in your sources, and the current translation language.

When you 'Import' the strings, the tool creates a text for the development language with the localized string found in the source file. The string is also used to define the text identifier. You can change both the text id, the development language text and of course you can add a translated text for each language defined in the database.

After importing texts, you can show a log report to see all texts found in the source file.

Warning: Localized string identifiers must be unique. If you import texts that already exist in the database, you get an error message in the log report.

Strings are linked to groups. Each group represents a file to be generated with the 'Export' function. You can specify the destination directory and the file name format for .str files. Strings are exported to .str files for a given language.

With the 'Organize' function you can change the group the texts belong to. This function is important because it allows you to group texts by subject. You typically put texts used in all programs into a 'Common' group.

Sources files are not modified by this tool when you change the localized string identifier. In order to simplify string management, we recommend you to write directly clear string identifiers in source files.

For example, instead of writing:

    MENU %"Customers"
      COMMAND %"Add"
              %"Append new customer record"

write:

    MENU %"customer.menu.title"
      COMMAND %"customer.cmd.add"
              %"customer.cmd.add.comment"

 
