# Localized Strings translation tool

## Description

This tool handles localized strings translation with a database.
You can import strings, search, group and translate to several languages,
then produce .str string files from the database content.

![Genero FGL Localized String Editor (GDC)](https://github.com/FourjsGenero/tool_fglstrmg/raw/master/docs/fglstrmg-screen-001.png)

## Prerequisites

* Database server supported by Genero (tested with Informix IDS 12)
* Genero BDL 3.10+
* Genero Browser Client 1.00.52+
* Genero Desktop Client 3.10+
* Genero Studio 3.10+
* GNU Make

## Compilation from command line

1. make clean all

## Compilation in Genero Studio

1. Load the fglstrmg.4pw project
2. Build the project

## Usage

1. Create a database supporting UTF-8 encoding
1. Start the program
2. Connect to the database
3. Create the tables to store localized strings
4. Define the global settings (default language, translation language)
5. Import existing strings from sources
6. Group strings together
7. Translate strings to target languages
8. Produce .str string files

## See also

See [Genero BDL documentation](http://www.4js.com/download/documentation) for more details about
Localized Strings.


## Bug fixes:


