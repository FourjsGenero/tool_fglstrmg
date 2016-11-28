# Localized Strings translation tool

## Description

This tool handles localized strings translation with a database.
You can import string, search and translate for several languages,
then produce .str string files from the database content.

## Prerequisites

* Database server supported by Genero (tested with Informix IDS 12)
* Genero BDL 3.00+
* Genero Desktop Client 3.00+
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
5. Import existing strings from .str files
6. Translate strings to target languages
7. Produce 

## See also

See [Genero BDL documentation](http://www.4js.com/download/documentation) for more details about
Localized Strings.


## Bug fixes:


