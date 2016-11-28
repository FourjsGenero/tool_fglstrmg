IMPORT os
IMPORT FGL fgltbasics
IMPORT FGL fgltdialogs
IMPORT FGL fgltfiledlg
IMPORT FGL fgllsm_param
IMPORT FGL fgllsm_group
IMPORT FGL fgllsm_lang
IMPORT FGL util

SCHEMA fglstrmg

CONSTANT toolname      = "fglstrmg"
CONSTANT tooltitle     = "Localized String Manager"
CONSTANT toolversion   = "2.1"

CONSTANT importable_files = "*.4gl|*.per|*.4tb|*.4tm|*.4sm|*.4ad"

DEFINE arr_fttext DYNAMIC ARRAY OF RECORD
                      fttext_ident LIKE fttext.fttext_ident,
                      fttext_num LIKE fttext.fttext_num,
                      fttext_locked LIKE fttext.fttext_locked
                  END RECORD
DEFINE arr_fttatt DYNAMIC ARRAY OF RECORD
                      color_ident  STRING,
                      color_num    STRING,
                      color_locked STRING
                  END RECORD

DEFINE gettext_stmt_prepared SMALLINT

DEFINE c_hastexts_declared SMALLINT

DEFINE curgroup INTEGER
DEFINE devlanguage, prev_devlanguage INTEGER
DEFINE curlanguage, prev_curlanguage INTEGER

DEFINE confdel CHAR(1)
DEFINE confimp CHAR(1)
DEFINE fnformat STRING

DEFINE txtrec RECORD
           fttext_ident LIKE fttext.fttext_ident,
           fttext_group LIKE fttext.fttext_group,
           fttext_num LIKE fttext.fttext_num,
           fttext_locked LIKE fttext.fttext_locked
       END RECORD
DEFINE txtarr DYNAMIC ARRAY OF RECORD
           fttext_ident LIKE fttext.fttext_ident,
           fttext_group LIKE fttext.fttext_group,
           fttext_num LIKE fttext.fttext_num,
           fttext_locked LIKE fttext.fttext_locked
       END RECORD

DEFINE txtnum LIKE fttext.fttext_num
DEFINE ident LIKE fttext.fttext_ident
DEFINE orgtext STRING
DEFINE thetext STRING

DEFINE saved SMALLINT

MAIN
  DEFINE r,i,p INTEGER
  DEFINE db, un, up VARCHAR(200)

  OPTIONS HELP file "fgllsm_help.iem"
  OPTIONS INPUT WRAP

  IF fglt_cmdarg_option_used( "V" ) THEN
     DISPLAY toolname || " " || toolversion
     EXIT PROGRAM 0
  END IF

  IF fglt_cmdarg_option_used( "h" ) THEN
     CALL display_usage( )
     EXIT PROGRAM 0
  END IF

  LET db = fglt_cmdarg_option_param( "db" )
  LET un = fglt_cmdarg_option_param( "un" )
  LET up = fglt_cmdarg_option_param( "up" )

  CALL ui.Interface.setText(tooltitle)

  DEFER INTERRUPT
  DEFER QUIT

  OPEN FORM f_main FROM "fgllsm_main"
  DISPLAY FORM f_main

  IF db IS NULL THEN
     CALL fglt_dblogin(tooltitle, "Enter database connection parameters", NULL,NULL,NULL)
          RETURNING r, db, un, up
     IF r == FALSE THEN
        EXIT PROGRAM 0
     END IF
  END IF

  WHENEVER ERROR CONTINUE
  IF un IS NOT NULL THEN
     CONNECT TO db USER un USING up
  ELSE
     CONNECT TO db
  END IF
  WHENEVER ERROR STOP
  IF sqlca.sqlcode < 0 THEN
     CALL __mbox_ok(tooltitle,"Could not connect to database '"||db||"'","stop")
     EXIT PROGRAM 1
  END IF

  IF NOT check_database() THEN
     CALL __mbox_ok(tooltitle,"Database tables not created, stopping program.","stop")
     EXIT PROGRAM 1
  END IF

  CALL load_params()
  CALL cmbgroup_fill()
  CALL cmbdevlang_fill()
  CALL cmbcurlang_fill()

  WHILE devlanguage=0
     CALL __mbox_ok("Parameters","Parameters are not set yet","exclamation")
     LET r = edit_params()
     IF NOT r THEN EXIT PROGRAM END IF
  END WHILE

  IF curgroup IS NULL THEN
     LET curgroup = 1
     LET curlanguage = 1
     CALL load_params()
  END IF

  CASE
   WHEN fglt_cmdarg_option_used( "ep" )
     LET r = edit_params()
     EXIT PROGRAM
   WHEN fglt_cmdarg_option_used( "eg" )
     CALL edit_groups()
     EXIT PROGRAM
   WHEN fglt_cmdarg_option_used( "el" )
     CALL edit_languages()
     EXIT PROGRAM
   WHEN fglt_cmdarg_option_used( "og" )
     LET r = fttext_organize()
     EXIT PROGRAM
  END CASE

  CALL fttext_fill(curgroup)

  DIALOG ATTRIBUTES(FIELD ORDER FORM, UNBUFFERED)

    DISPLAY ARRAY arr_fttext TO sa.* ATTRIBUTES(HELP=1)
       BEFORE ROW 
          CALL list_sync_fields(DIALOG)
          CALL list_setup(DIALOG)
    END DISPLAY

    INPUT BY NAME curgroup
          ATTRIBUTES(WITHOUT DEFAULTS,HELP=1)
       ON CHANGE curgroup
          CALL ftparam_set("CURGROUP",curgroup)
          CALL fttext_fill(curgroup)
          CALL DIALOG.setCurrentRow("sa",1)
          CALL list_sync_fields(DIALOG)
          CALL list_setup(DIALOG)
    END INPUT

    INPUT BY NAME ident,
                  devlanguage, orgtext,
                  curlanguage, thetext
          ATTRIBUTES(WITHOUT DEFAULTS,HELP=1)

       BEFORE FIELD devlanguage
          LET prev_devlanguage = devlanguage

       ON CHANGE devlanguage
          IF devlanguage IS NULL THEN
             CALL __mbox_ok("Translation language","The development language cannot be NULL.","stop")
             LET devlanguage = prev_devlanguage
             NEXT FIELD devlanguage
          END IF
          IF devlanguage == curlanguage THEN
             CALL __mbox_ok("Development language","The development language cannot be the same as translation language.","stop")
             LET devlanguage = prev_devlanguage
             NEXT FIELD devlanguage
          END IF
          CALL ftparam_set("DEVLANG",devlanguage)
          CALL list_sync_fields(DIALOG)

       BEFORE FIELD curlanguage
          LET prev_curlanguage = curlanguage

       ON CHANGE curlanguage
          IF curlanguage IS NULL THEN
             CALL __mbox_ok("Translation language","The translation language cannot be NULL.","stop")
             LET curlanguage = prev_curlanguage
             NEXT FIELD curlanguage
          END IF
          IF curlanguage == devlanguage THEN
             CALL __mbox_ok("Translation language","The translation language cannot be the same as development language.","stop")
             LET curlanguage = prev_curlanguage
             NEXT FIELD curlanguage
          END IF
          CALL ftparam_set("CURLANG",curlanguage)
          CALL list_sync_fields(DIALOG)

       AFTER FIELD ident
          LET i = DIALOG.getCurrentRow("sa")
          LET arr_fttext[i].fttext_ident = ident

       AFTER INPUT
          LET i = DIALOG.getCurrentRow("sa")
          IF NOT text_save(DIALOG, i) THEN CONTINUE DIALOG END IF
          CALL list_setup(DIALOG)

    END INPUT

    BEFORE DIALOG
       LET saved = TRUE
       CALL DIALOG.setArrayAttributes("sa",arr_fttatt)
       CALL list_sync_fields(DIALOG)
       CALL list_setup(DIALOG)

    ON ACTION about
       CALL show_about()

    ON ACTION parameters
       LET r = edit_params()

    ON ACTION groups
       CALL edit_groups()
       CALL cmbgroup_fill()
       IF ftgroup_getident(curgroup) IS NULL THEN LET curgroup = 0 END IF
       CALL list_setup(DIALOG)

    ON ACTION languages
       CALL edit_languages()
       CALL cmbdevlang_fill()
       IF ftlang_getident(devlanguage) IS NULL THEN LET devlanguage = 0 END IF
       CALL cmbcurlang_fill()
       IF ftlang_getident(curlanguage) IS NULL THEN LET curlanguage = 0 END IF
       CALL list_setup(DIALOG)

    ON ACTION close
       IF __mbox_yn("Quit","Are you sure you want to quit?","question") THEN EXIT DIALOG END IF

    ON ACTION organize
       IF NOT fttext_organize() THEN CONTINUE DIALOG END IF
       CALL fttext_fill(curgroup)
       CALL DIALOG.setCurrentRow("sa",1)
       CALL list_setup(DIALOG)

    ON ACTION lcktxt
       LET i = DIALOG.getCurrentRow("sa")
       LET txtnum = arr_fttext[i].fttext_num
       IF fttext_switchlock(txtnum,arr_fttext[i].fttext_locked) THEN
          LET arr_fttext[i].fttext_locked = fttext_switchyn(arr_fttext[i].fttext_locked)
          CALL fttext_set_color(i)
       END IF
       CALL list_setup(DIALOG)

    ON ACTION prvtxt
       LET i = DIALOG.getCurrentRow("sa")
       IF i>1 THEN
          IF NOT text_save(DIALOG, i) THEN CONTINUE DIALOG END IF
          CALL DIALOG.setCurrentRow("sa",i-1)
          CALL list_sync_fields(DIALOG)
       END IF
       CALL list_setup(DIALOG)

    ON ACTION nxttxt
       LET i = DIALOG.getCurrentRow("sa")
       IF i<DIALOG.getArrayLength("sa") THEN
          IF NOT text_save(DIALOG, i) THEN CONTINUE DIALOG END IF
          CALL DIALOG.setCurrentRow("sa",i+1)
          CALL list_sync_fields(DIALOG)
       END IF
       CALL list_setup(DIALOG)

    ON ACTION delgroup
       IF NOT fttext_delgroup(curgroup) THEN CONTINUE DIALOG END IF
       LET curgroup = 0
       CALL fttext_fill(curgroup)
       CALL DIALOG.setCurrentRow("sa",1)
       CALL list_sync_fields(DIALOG)
       CALL list_setup(DIALOG)

    ON ACTION import
       IF NOT fttext_import() THEN CONTINUE DIALOG END IF
       CALL fttext_fill(curgroup)
       CALL DIALOG.setCurrentRow("sa",1)
       CALL list_setup(DIALOG)

    ON ACTION export
       CALL fttext_export()

    ON ACTION search
       LET txtnum = fttext_search()
       IF txtnum>0 THEN
          CALL list_lookup_fttext(DIALOG, txtnum)
          CALL list_setup(DIALOG)
       END IF

    ON ACTION newtxt
       LET i = DIALOG.getCurrentRow("sa")
       IF NOT text_save(DIALOG, i) THEN CONTINUE DIALOG END IF
       CALL DIALOG.appendRow("sa")
       LET i = DIALOG.getArrayLength("sa")
       CALL fttext_create(curgroup)
            RETURNING txtnum, ident
       LET arr_fttext[i].fttext_num = txtnum
       LET arr_fttext[i].fttext_ident = ident
       LET arr_fttext[i].fttext_locked = 'n'
       LET orgtext = NULL
       LET thetext = NULL
       CALL DIALOG.setCurrentRow("sa",i)
       CALL list_setup(DIALOG)
       NEXT FIELD ident

    ON ACTION cpytxt
       LET p = DIALOG.getCurrentRow("sa")
       IF p<=0 THEN CONTINUE DIALOG END IF
       IF NOT text_save(DIALOG, p) THEN CONTINUE DIALOG END IF
       CALL DIALOG.appendRow("sa")
       LET i = DIALOG.getArrayLength("sa")
       CALL fttext_copy(arr_fttext[p].fttext_num, curgroup)
            RETURNING txtnum, ident
       LET arr_fttext[i].fttext_num = txtnum
       LET arr_fttext[i].fttext_ident = ident
       LET arr_fttext[i].fttext_locked = 'n'
       LET orgtext = fttrans_gettext(txtnum,devlanguage)
       LET thetext = fttrans_gettext(txtnum,curlanguage)
       CALL DIALOG.setCurrentRow("sa",i)
       CALL list_setup(DIALOG)
       NEXT FIELD ident

    ON ACTION deltxt
       LET i = DIALOG.getCurrentRow("sa")
       IF i<=0 THEN CONTINUE DIALOG END IF
       IF arr_fttext[i].fttext_locked=="y" THEN
          CALL __mbox_ok("Delete","You cannot delete a locked text","stop")
          CONTINUE DIALOG
       END IF
       LET txtnum = arr_fttext[i].fttext_num
       IF confdel="y" THEN
          IF NOT __mbox_yn("Delete","Are you sure you want to delete this text?","question") THEN
             CONTINUE DIALOG
          END IF
       END IF
       CALL fttext_delete(txtnum)
       CALL DIALOG.deleteRow("sa",i)
       LET i = DIALOG.getCurrentRow("sa")
       IF i>0 THEN
          LET txtnum = arr_fttext[i].fttext_num
          LET ident = arr_fttext[i].fttext_ident
          LET orgtext = fttrans_gettext(txtnum,devlanguage)
          LET thetext = fttrans_gettext(txtnum,curlanguage)
       ELSE
          LET txtnum = NULL
          LET ident = NULL
          LET orgtext = NULL
          LET thetext = NULL
       END IF
       CALL list_setup(DIALOG)

    ON ACTION dialogtouched
       IF DIALOG.getCurrentItem() == "curgroup" THEN CONTINUE DIALOG END IF
       LET saved = FALSE
       CALL list_setup(DIALOG)

    ON ACTION save
       IF DIALOG.validate(NULL) < 0 THEN CONTINUE DIALOG END IF
       LET i = DIALOG.getCurrentRow("sa")
       IF NOT text_save(DIALOG, i) THEN CONTINUE DIALOG END IF
       CALL list_setup(DIALOG)

  END DIALOG

END MAIN

FUNCTION text_save(d, row)
  DEFINE d ui.Dialog
  DEFINE row INTEGER
  IF row<=0 THEN RETURN TRUE END IF
  LET txtnum = arr_fttext[row].fttext_num
  IF d.getFieldTouched("ident") THEN
     IF NOT fttext_setident(txtnum,ident) THEN
        CALL __mbox_ok("Modify","SQL error:\n"||SQLERRMESSAGE,"stop")
        CALL d.nextField("ident")
     END IF
  END IF
  IF d.getFieldTouched("orgtext") THEN
     CALL fttrans_settext(txtnum,devlanguage,orgtext)
  END IF
  IF d.getFieldTouched("thetext") THEN
     CALL fttrans_settext(txtnum,curlanguage,thetext)
  END IF
  LET saved = TRUE
  CALL d.setFieldTouched("ident",FALSE)
  CALL d.setFieldTouched("orgtext",FALSE)
  CALL d.setFieldTouched("thetext",FALSE)
  RETURN TRUE
END FUNCTION

FUNCTION list_sync_fields(d)
  DEFINE d ui.Dialog
  DEFINE i INTEGER
  LET i = d.getCurrentRow("sa")
  IF i>0 THEN
     LET txtnum = arr_fttext[i].fttext_num
     LET ident = arr_fttext[i].fttext_ident
     LET orgtext = fttrans_gettext(txtnum,devlanguage)
     LET thetext = fttrans_gettext(txtnum,curlanguage)
  ELSE
     LET txtnum = NULL
     LET ident = NULL
     LET orgtext = NULL
     LET thetext = NULL
  END IF
END FUNCTION

FUNCTION list_setup(d)
  DEFINE d ui.Dialog
  DEFINE i,l INTEGER
  LET i = d.getCurrentRow("sa")
  IF i>0 THEN
     LET l = (arr_fttext[i].fttext_locked=="y")
  ELSE
     LET l = TRUE
  END IF
  CALL d.setActionActive("dialogtouched", saved)
  CALL d.setActionActive("save", NOT saved)
  CALL d.setFieldActive("ident", (i>0) AND NOT l)
  CALL d.setFieldActive("orgtext", (i>0) AND NOT l)
  CALL d.setFieldActive("thetext", (i>0) AND NOT l)
  CALL d.setActionActive("deltxt", (i>0) AND NOT l)
  CALL d.setActionActive("cpytxt", (i>0))
  CALL d.setActionActive("lcktxt", (i>0))
  CALL d.setActionActive("prvtxt", (i>1))
  CALL d.setActionActive("nxttxt", (i<d.getArrayLength("sa")))
END FUNCTION

FUNCTION fttext_delgroup(agroup)
  DEFINE agroup INTEGER
  IF agroup<1 THEN
     CALL __mbox_ok("Delete Group","You cannot delete this group.","stop")
     RETURN FALSE
  END IF
  IF NOT __mbox_yn("Delete Group",
         "Are you sure you want to delete all texts from group '"||ftgroup_getident(agroup)||"' ?",
         "question") THEN RETURN FALSE END IF
  WHENEVER ERROR CONTINUE
  DELETE FROM fttrans where fttrans_text in
         (SELECT fttext_num FROM fttext WHERE fttext_group = agroup)
  IF sqlca.sqlcode THEN
     CALL __mbox_ok("Delete Group","Error while deleting from fttrans:\n"||sqlerrmessage,"stop")
     RETURN TRUE -- reload!
  END IF
  DELETE FROM fttext WHERE fttext_group=agroup
  IF sqlca.sqlcode THEN
     CALL __mbox_ok("Delete Group","Error while deleting from fttext:\n"||sqlerrmessage,"stop")
     RETURN TRUE -- reload!
  END IF
  DELETE FROM ftgroup WHERE ftgroup_num=agroup
  IF sqlca.sqlcode THEN
     CALL __mbox_ok("Delete Group","Error while deleting from ftgroup:\n"||sqlerrmessage,"stop")
     RETURN TRUE -- reload!
  END IF
  WHENEVER ERROR STOP
  RETURN TRUE -- reload!
END FUNCTION

FUNCTION filename_toident(filename)
  DEFINE filename STRING
  DEFINE ident base.stringbuffer
  DEFINE i,l INTEGER
  DEFINE c CHAR(1)
  LET ident=base.stringbuffer.create()
  CALL ident.append(filename)
  LET i=1
  LET l=ident.getLength()
  FOR i=1 TO l
    LET c=ident.getCharAt(i)
    IF c="." OR c=" " THEN
       CALL ident.replaceAt(i,1,"_")
    END IF
  END FOR
  RETURN ident.toString()
END FUNCTION

FUNCTION edit_groups()
  CALL ftgroup_edit()
END FUNCTION

FUNCTION edit_languages()
  CALL ftlang_edit()
END FUNCTION

FUNCTION edit_params()
  DEFINE s INTEGER
  LET s = ftparam_edit()
  IF s THEN
     CALL load_params()
  END IF
  RETURN s
END FUNCTION

FUNCTION load_params()
  LET confdel     = ftparam_get("CONFDEL")
  LET confimp     = ftparam_get("CONFIMP")
  LET fnformat    = ftparam_get("FNFORMAT")
  LET curgroup    = ftparam_get("CURGROUP")
  IF curgroup IS NULL THEN
     CALL ftparam_set("CURGROUP",0)
     LET curgroup = 0
  END IF
  LET devlanguage = ftparam_get("DEVLANG")
  IF devlanguage IS NULL THEN
     CALL ftparam_set("DEVLANG",0)
     LET devlanguage = 0
  END IF
  LET curlanguage = ftparam_get("CURLANG")
  IF curlanguage IS NULL THEN
     CALL ftparam_set("CURLANG",0)
     LET curlanguage = 0
  END IF
END FUNCTION

FUNCTION cmbgroup_fill()
  DEFINE cb ui.ComboBox
  LET cb = ui.ComboBox.forName("formonly.curgroup")
  CALL cmbinit_ftgroup(cb)
END FUNCTION

FUNCTION cmbdevlang_fill()
  DEFINE cb ui.ComboBox
  LET cb = ui.ComboBox.forName("formonly.devlanguage")
  CALL cmbinit_ftlang(cb)
END FUNCTION

FUNCTION cmbcurlang_fill()
  DEFINE cb ui.ComboBox
  LET cb = ui.ComboBox.forName("formonly.curlanguage")
  CALL cmbinit_ftlang(cb)
END FUNCTION

FUNCTION fttrans_gettext(num,lang)
  DEFINE num INTEGER
  DEFINE lang INTEGER
  DEFINE value LIKE fttrans.fttrans_value
  DEFINE line INTEGER
  DEFINE text STRING

  IF NOT gettext_stmt_prepared THEN
     LET gettext_stmt_prepared = TRUE
     DECLARE c_gettext CURSOR for
         SELECT fttrans_value, fttrans_line
           FROM fttrans
          WHERE fttrans_text=? AND fttrans_lang=?
          ORDER BY fttrans_line
  END IF

  LET text = NULL
  FOREACH c_gettext USING num, lang INTO value, line
    IF text IS NULL THEN
       LET text = value
    ELSE
       LET text = text || value
    END IF
  END FOREACH

  RETURN text

END FUNCTION

FUNCTION fttrans_settext(num,lang,text)
  CONSTANT value_size=200
  DEFINE num INTEGER
  DEFINE lang INTEGER
  DEFINE text STRING
  DEFINE value LIKE fttrans.fttrans_value
  DEFINE line,p1,p2 INTEGER

  # FIXME: Splitting in the middle of a multibyte character will lose
  # the character... Must use and mblen() equivalent to split...
  DELETE FROM fttrans WHERE fttrans_text = num AND fttrans_lang = lang
  LET line=1
  WHILE TRUE
    LET p1=((line-1)*value_size)+1
    LET p2=p1+value_size-1
    IF p2>text.getLength() THEN
       LET p2=text.getLength()
    END IF
    LET value = text.subString(p1,p2)
    IF value IS NULL THEN EXIT WHILE END IF
    INSERT INTO fttrans VALUES ( num, lang, line, value )
    LET line=line+1
  END WHILE

END FUNCTION

FUNCTION fttext_setident(num,ident)
  DEFINE num INTEGER
  DEFINE ident LIKE fttext.fttext_ident
  WHENEVER ERROR CONTINUE
  UPDATE fttext SET fttext_ident = ident WHERE fttext_num = num
  WHENEVER ERROR STOP
  RETURN (sqlca.sqlcode==0)
END FUNCTION

FUNCTION fttext_switchyn(yn)
  DEFINE yn CHAR(1)
  IF yn=='y' THEN RETURN 'n' ELSE RETURN 'y' END IF
END FUNCTION

FUNCTION fttext_switchlock(num,yn)
  DEFINE num INTEGER
  DEFINE yn CHAR(1)
  WHENEVER ERROR CONTINUE
  LET yn=fttext_switchyn(yn)
  UPDATE fttext SET fttext_locked = yn WHERE fttext_num = num
  WHENEVER ERROR STOP
  RETURN (sqlca.sqlcode==0)
END FUNCTION

FUNCTION fttext_set_color(row)
  DEFINE row INTEGER
  DEFINE c STRING
  IF arr_fttext[row].fttext_locked == "y" THEN LET c = "reverse lightblue" END IF
  LET arr_fttatt[row].color_num = c
  LET arr_fttatt[row].color_ident = c
  LET arr_fttatt[row].color_locked = c
END FUNCTION

FUNCTION fttext_fill(agroup)
  DEFINE agroup INTEGER
  DEFINE rec_fttext RECORD
             fttext_ident LIKE fttext.fttext_ident,
             fttext_num LIKE fttext.fttext_num,
             fttext_locked LIKE fttext.fttext_locked
         END RECORD
  DEFINE i INTEGER
  DECLARE c_fttext CURSOR FOR
          SELECT fttext_ident, fttext_num, fttext_locked
            FROM fttext where fttext_group = agroup
            ORDER BY fttext_ident
  LET i=0
  CALL arr_fttext.clear()
  CALL arr_fttatt.clear()
  FOREACH c_fttext INTO rec_fttext.*
    LET i=i+1
    LET arr_fttext[i].fttext_num = rec_fttext.fttext_num
    LET arr_fttext[i].fttext_ident = rec_fttext.fttext_ident
    LET arr_fttext[i].fttext_locked = rec_fttext.fttext_locked
    CALL fttext_set_color(i)
  END FOREACH
END FUNCTION

FUNCTION fttext_newid()
  DEFINE id INTEGER
  SELECT MAX(fttext_num)+1 INTO id FROM fttext 
  IF id IS NULL THEN LET id=1 END IF
  RETURN id
END FUNCTION

FUNCTION fttext_create(agroup)
  DEFINE agroup INTEGER
  DEFINE num LIKE fttext.fttext_num
  DEFINE ident LIKE fttext.fttext_ident
  LET num = fttext_newid()
  LET ident = "text_"|| num
  INSERT INTO fttext VALUES ( num, ident, agroup, 'n' )
  RETURN num, ident
END FUNCTION

FUNCTION fttext_delete(num)
  DEFINE num LIKE fttext.fttext_num
  DELETE FROM fttrans WHERE fttrans_text=num
  DELETE FROM fttext WHERE fttext_num=num
END FUNCTION

FUNCTION fttext_copy(anum,agroup)
  DEFINE anum,cnum LIKE fttext.fttext_num
  DEFINE agroup LIKE fttext.fttext_group 
  DEFINE ident LIKE fttext.fttext_ident
  DEFINE text STRING
  DEFINE i,maxlang INTEGER
  CALL fttext_create(agroup) RETURNING cnum, ident
  LET maxlang=ftlang_getmax()
  FOR i=1 TO maxlang
      LET text = fttrans_gettext(anum,i)
      IF text IS NOT NULL THEN
         CALL fttrans_settext(cnum,i,text)
      END IF
  END FOR
  RETURN cnum, ident
END FUNCTION

FUNCTION fttext_import()
  DEFINE filename STRING
  DEFINE agroup INTEGER
  DEFINE grpname, ident STRING
  DEFINE importdir STRING
  DEFINE i,rv,cnt,newgroup INTEGER

  LET importdir = ftparam_get("IMPORTDIR")
  LET filename = fglt_file_opendlg(NULL,importdir,NULL,importable_files,"sh")
  IF filename IS NULL THEN RETURN FALSE END IF

  CALL ftparam_set("IMPORTDIR",os.Path.dirname(filename))

  LET newgroup = TRUE
  IF curgroup IS NOT NULL THEN
     IF confimp="y" THEN
        LET newgroup = __mbox_yn("Import","Do you want to import texts into a new group?","question")
     END IF
  END IF
  IF NOT newgroup THEN
     LET agroup = curgroup -- Import into current group
  ELSE
     LET grpname = filename_toident(os.Path.basename(filename))
     IF ftgroup_exists(grpname) THEN
        IF NOT __mbox_yn("Import",
          "The group '"||grpname||"' exists in the database, do you want to continue?","information") THEN
          RETURN FALSE
        END IF
     END IF
     LET i=1
     WHILE ftgroup_exists(grpname)
        LET i=i+1
        LET grpname = filename_toident(os.Path.basename(filename)) || "_" || i
     END WHILE
     IF confimp="y" THEN
        CALL __mbox_ok("Import",
          "A new group '"||grpname||"' will be created to hold all the new texts.","information")
     END IF
     CALL ftgroup_create(grpname) RETURNING agroup,ident
     IF agroup==-1 THEN
        CALL __mbox_ok("Import","Could not create group in database!","stop")
        RETURN FALSE
     END IF
     CALL ui.Interface.refresh() -- remove message box
  END IF

  CALL fglt_wait_open("Import")
  CALL fglt_log_open()
  BEGIN WORK
  CASE os.Path.extension(filename)
     WHEN "4gl" CALL fttext_import_from_cmd(agroup,devlanguage,"fglcomp -m \""||filename||"\"") RETURNING rv, cnt
     WHEN "per" CALL fttext_import_from_cmd(agroup,devlanguage,"fglform -m \""||filename||"\"") RETURNING rv, cnt
     OTHERWISE  CALL fttext_import_from_xml(agroup,devlanguage,filename) RETURNING rv, cnt
  END CASE
  CALL fglt_wait_close()

  IF rv>=0 THEN
     IF cnt==0 THEN
        CALL __mbox_ok("Import","No localized string found in the file!","information")
        LET rv=-3
     END IF
     IF rv>0 THEN
        IF __mbox_yn("Import","Some warnings raised during the import!\n" ||
                          "Do you want to see the log report?","question") THEN
           CALL fglt_log_show()
        END IF
        IF newgroup THEN
           IF NOT __mbox_yn("Import","Do you want to keep the new group '"||grpname||"'?","question") THEN
              LET rv=-1
           END IF
        END IF
     END IF
  ELSE
     CALL __mbox_ok("Import","An error occured during import, no texts imported.","stop")
  END IF

  IF rv>=0 THEN
     COMMIT WORK
     IF newgroup THEN
        LET curgroup = agroup
     END IF
  ELSE
     IF newgroup THEN
        DELETE FROM ftgroup WHERE ftgroup_num=agroup
     END IF
     ROLLBACK WORK
  END IF

  CALL fglt_log_close()

  RETURN (rv>=0)

END FUNCTION

FUNCTION fttext_import_from_cmd(agroup,devlang,cmd)
  DEFINE agroup INTEGER
  DEFINE devlang INTEGER
  DEFINE cmd STRING
  DEFINE ch base.Channel
  DEFINE line STRING
  DEFINE t,rv INTEGER
  LET rv=0
  LET ch=base.Channel.create()
  CALL ch.setDelimiter(NULL)
  WHENEVER ERROR CONTINUE
  CALL ch.openPipe(cmd,'r')
  LET int_flag=FALSE
  LET t=0
  WHILE ch.read([line])
     LET t=t+1
     LET rv = fttext_impline(agroup,devlang,line)
     CALL fglt_wait_show(SFMT("Importing text... %1",t))
     IF int_flag THEN EXIT WHILE END IF
  END WHILE
  IF status THEN
     CALL __mbox_ok("Import","Could not read from channel: "||status,"stop")
     LET rv=-1
  END IF
  IF int_flag THEN
     CALL __mbox_ok("Import","Import interrupted by user","information")
     LET rv=-2
  END IF
  WHENEVER ERROR STOP
  CALL ch.close()
  LET int_flag=FALSE
  RETURN rv, t
END FUNCTION

FUNCTION fttext_import_from_xml(agroup,devlang,xml)
  DEFINE agroup INTEGER
  DEFINE devlang INTEGER
  DEFINE xml STRING
  DEFINE saxdh om.XmlReader
  DEFINE attrs om.SaxAttributes
  DEFINE event STRING
  DEFINE domdoc om.DomDocument
  DEFINE lasta om.DomNode
  DEFINE t,i,r,rv,cnt INTEGER
  LET rv=0
  LET cnt=0
  LET saxdh = om.XmlReader.createFileReader(xml)
  IF saxdh IS NULL THEN
     CALL __mbox_ok("Import","Could not read from XML file: "||xml,"stop")
     RETURN FALSE, 0
  END IF
  LET domdoc = om.DomDocument.create("tmp")
  LET lasta = domdoc.getDocumentElement()
  LET event = saxdh.read()
  LET int_flag=FALSE
  LET t=0
  WHILE event IS NOT NULL
    CASE event
       WHEN "StartElement"
          IF saxdh.getTagName() == "LStr" THEN
             LET attrs = saxdh.getAttributes()
             FOR i=1 TO attrs.getLength()
                 LET t=t+1
                 CALL fglt_wait_show(SFMT("Importing text... %1",t))
                 LET r=fttext_imptext(
                             agroup,
                             attrs.getValueByIndex(i),
                             devlang,
                             lasta.getAttribute(attrs.getName(i))
                      )
                 IF r!=0 THEN LET rv=r END IF
             END FOR
          ELSE
             LET attrs = saxdh.getAttributes()
             FOR i=1 TO attrs.getLength()
                 CALL lasta.setAttribute(attrs.getName(i),attrs.getValueByIndex(i))
             END FOR
          END IF
    END CASE
    LET event = saxdh.read()
    IF int_flag THEN EXIT WHILE END IF
  END WHILE
  IF int_flag THEN
     CALL __mbox_ok("Import","Import interrupted by user","information")
     LET rv=-2
  END IF
  LET int_flag=FALSE
  RETURN rv, t
END FUNCTION

FUNCTION fttext_impline(agroup,devlang,line)
  DEFINE agroup INTEGER
  DEFINE devlang INTEGER
  DEFINE line STRING
  DEFINE ident LIKE fttext.fttext_ident
  DEFINE text STRING
  DEFINE p INTEGER
  LET p = line.getIndexOf('"="',2)
  IF p IS NULL THEN RETURN FALSE END IF
  LET ident = line.subString(2,p-1)
  LET text = line.subString(p+3,line.getLength()-1)
  RETURN fttext_imptext(agroup,ident,devlang,text)
END FUNCTION

FUNCTION fttext_imptext(agroup,ident,devlang,devtext)
  DEFINE agroup INTEGER
  DEFINE ident LIKE fttext.fttext_ident
  DEFINE devlang INTEGER
  DEFINE devtext STRING
  DEFINE num INTEGER
  DEFINE dumid INTEGER
  DEFINE rv INTEGER
  CALL fttext_create(agroup) RETURNING num, dumid
  LET rv=0
  IF NOT fttext_setident(num,ident) THEN
     CALL fglt_log_write("*** WARNING *** Dupplicate text: ["||ident||"]")
     CALL fttext_delete(num)
     LET rv=1
  ELSE
     CALL fttrans_settext(num,devlang,devtext)
     CALL fglt_log_write("["||devtext||"]")
  END IF
  RETURN rv
END FUNCTION

FUNCTION cmbexplang_fill()
  DEFINE cb ui.ComboBox
  LET cb = ui.ComboBox.forName("formonly.explanguage")
  CALL cmbinit_ftlang(cb)
END FUNCTION

FUNCTION fttext_export()
  DEFINE exportdir,tmp,fnformat STRING
  DEFINE explanguage INTEGER
  DEFINE dirname STRING
  DEFINE i,rv,fcnt INTEGER
  DEFINE grprec RECORD LIKE ftgroup.*
  DEFINE grparr DYNAMIC ARRAY OF RECORD
             selected SMALLINT,
             ftgroup_ident LIKE ftgroup.ftgroup_ident,
             ftgroup_num LIKE ftgroup.ftgroup_num
         END RECORD

  LET exportdir   = ftparam_get("EXPORTDIR")
  LET explanguage = ftparam_get("EXPORTLANG")
  LET fnformat    = ftparam_get("FNFORMAT")

  OPEN WINDOW w_export WITH FORM "fgllsm_export" ATTRIBUTES(STYLE="dialog")
  CALL cmbexplang_fill()

  DECLARE c_grparr CURSOR FOR
          SELECT * FROM ftgroup WHERE ftgroup_num>0 ORDER BY ftgroup_ident
  LET i=0
  FOREACH c_grparr INTO grprec.*
    LET i=i+1
    LET grparr[i].selected = 0
    LET grparr[i].ftgroup_ident = grprec.ftgroup_ident
    LET grparr[i].ftgroup_num   = grprec.ftgroup_num
  END FOREACH

  DIALOG ATTRIBUTES(UNBUFFERED, FIELD ORDER FORM)

    INPUT BY NAME exportdir, explanguage, fnformat
        ATTRIBUTES(WITHOUT DEFAULTS)
        AFTER FIELD exportdir
           IF exportdir NOT MATCHES "*%1*" THEN
              CALL __mbox_ok("Export", "Error: Export dir must hold %1 to identify language", "stop")
              NEXT FIELD exportdir
           END IF
    END INPUT

    INPUT ARRAY grparr FROM sa.*
        ATTRIBUTES(WITHOUT DEFAULTS,
                   DELETE ROW=FALSE,
                   APPEND ROW=FALSE,
                   INSERT ROW=FALSE,
                   AUTO APPEND=FALSE)
    END INPUT

    ON ACTION ofile
       LET tmp = fglt_file_opendlg(NULL,exportdir,NULL,"DIR","cd,dd,sh")
       IF tmp IS NOT NULL THEN
          LET exportdir = tmp
       END IF

    ON ACTION sel_all
       FOR i=1 TO DIALOG.getArrayLength("sa")
           LET grparr[i].selected = 1
       END FOR

    ON ACTION desel_all
       FOR i=1 TO DIALOG.getArrayLength("sa")
           LET grparr[i].selected = 0
       END FOR

    ON ACTION accept
       LET rv = TRUE
       ACCEPT DIALOG

    ON ACTION cancel
       LET rv = FALSE
       EXIT DIALOG

  END DIALOG

  IF rv THEN
     CALL ftparam_set("EXPORTDIR", exportdir)
     CALL ftparam_set("EXPORTLANG", explanguage)
     CALL ftparam_set("FNFORMAT", fnformat)
     LET fcnt=0
     LET int_flag = FALSE
     LET dirname = SFMT(exportdir, ftlang_getident(explanguage))
     IF NOT os.Path.isdirectory(dirname) THEN
        IF NOT __mbox_yn("Export",SFMT("Directory %1 does not exist, create?", dirname), "question") THEN
           GOTO export_end
        END IF
        IF NOT os.Path.mkdir(dirname) THEN
           CALL __mbox_ok("Export",SFMT("Could not create directory %1, stopping export.", dirname), "stop")
           GOTO export_end
        END IF
     END IF
     CALL fglt_progress_open("Export","Generating files...",1,grparr.getLength())
     FOR i=1 TO grparr.getLength()
       CALL fglt_progress_show(i)
       IF grparr[i].selected THEN
         CALL fttext_exportgrp(dirname,explanguage,fnformat,grparr[i].ftgroup_num)
         LET fcnt = fcnt + 1
       END IF
       IF int_flag THEN EXIT FOR END IF
     END FOR
     CALL fglt_progress_close()
     IF int_flag THEN
        CALL __mbox_ok("Export","Export interrupted by user.","exclamation")
     ELSE
        CALL __mbox_ok("Export",SFMT("Export finished: %1 files created.",fcnt),"information")
     END IF
  END IF

LABEL export_end:
  CLOSE WINDOW w_export

END FUNCTION

FUNCTION fttrans_hastexts(agroup,alang)
  DEFINE agroup,alang INTEGER
  DEFINE rv INTEGER
  IF NOT c_hastexts_declared THEN
     DECLARE c_hastexts CURSOR FOR
      SELECT fttrans_line FROM fttrans, fttext
       WHERE fttrans_text=fttext_num
         AND fttext_group=? AND fttrans_lang=?
     LET c_hastexts_declared = TRUE
  END IF
  OPEN c_hastexts USING agroup, alang
  FETCH c_hastexts
  LET rv=(sqlca.sqlcode==0)
  CLOSE c_hastexts
  RETURN rv
END FUNCTION

FUNCTION fttext_exportgrp(dirname,explanguage,fnformat,agroup)
  DEFINE dirname STRING
  DEFINE explanguage INTEGER
  DEFINE fnformat STRING
  DEFINE agroup INTEGER
  DEFINE filename STRING
  DEFINE textnum INTEGER
  DEFINE textident LIKE fttext.fttext_ident
  DEFINE ch base.Channel
  DEFINE line STRING
  DEFINE cnttext INTEGER

  IF NOT fttrans_hastexts(agroup,explanguage) THEN RETURN END IF

  LET ch = base.Channel.create()
  CALL ch.setDelimiter(NULL)

  DECLARE c_exptext CURSOR FOR
          SELECT fttext_num, fttext_ident
            FROM fttext WHERE fttext_group=agroup

  LET filename = dirname || os.Path.separator() || SFMT(fnformat, ftgroup_getident(agroup))
  CALL ch.openFile(filename,"w")
  SELECT COUNT(fttext_num) INTO cnttext FROM fttext WHERE fttext_group=agroup
  FOREACH c_exptext INTO textnum, textident
      LET line = '"'||textident||'"="'||fttrans_gettext(textnum,explanguage)||'"'
      IF line IS NOT NULL THEN
         CALL ch.write([line])
      END IF
  END FOREACH

  CALL ch.close()

END FUNCTION

FUNCTION fttext_search()
   DEFINE s STRING
   DEFINE t INTEGER
   DEFINE a DYNAMIC ARRAY OF RECORD
              fttext_ident LIKE fttext.fttext_ident,
              ftgroup_ident LIKE ftgroup.ftgroup_ident,
              fttext_num LIKE fttext.fttext_num
            END RECORD
   OPEN WINDOW wsearch WITH FORM "fgllsm_search"-- ATTRIBUTES(STYLE="dialog4")
   LET t = -1
   DIALOG ATTRIBUTES(FIELD ORDER FORM, UNBUFFERED)
      CONSTRUCT BY NAME s ON fttrans_lang, fttext_ident, fttrans_value
      END CONSTRUCT

      DISPLAY ARRAY a TO sa.*
      END DISPLAY

      BEFORE DIALOG
         CALL DIALOG.setActionActive("select",FALSE)
      ON ACTION accept
         CALL fttext_query(s, a)
         IF a.getLength()==0 THEN
            CALL __mbox_ok("Search","No text found was found!","exclamation")
         END IF
         CALL DIALOG.setActionActive("select", a.getLength()>0)
      ON ACTION select
         LET t = a[DIALOG.getCurrentRow("sa")].fttext_num
         EXIT DIALOG
      ON ACTION cancel
         EXIT DIALOG
      ON ACTION close
         EXIT DIALOG
   END DIALOG
   CLOSE WINDOW wsearch
   IF t<=0 THEN RETURN 0 END IF
   RETURN t
END FUNCTION

FUNCTION list_lookup_fttext(d, t)
   DEFINE d ui.Dialog
   DEFINE t INTEGER
   DEFINE n, g INTEGER
   SELECT fttext_group INTO g FROM fttext WHERE fttext_num=t
   IF SQLCA.SQLCODE == 100 THEN RETURN END IF
   LET curgroup = g
   CALL fttext_fill(curgroup)
   FOR n=1 TO arr_fttext.getLength()
     IF arr_fttext[n].fttext_num == t THEN
        EXIT FOR
     END IF
   END FOR
   CALL d.setCurrentRow("sa",n)
   CALL list_sync_fields(d)
   CALL list_setup(d)
END FUNCTION

FUNCTION fttext_query(s,a)
   DEFINE s STRING
   DEFINE a DYNAMIC ARRAY OF RECORD
              fttext_ident LIKE fttext.fttext_ident,
              ftgroup_ident LIKE ftgroup.ftgroup_ident,
              fttext_num LIKE fttext.fttext_num
            END RECORD
   DEFINE r RECORD
              fttext_ident LIKE fttext.fttext_ident,
              ftgroup_ident LIKE ftgroup.ftgroup_ident,
              fttext_num LIKE fttext.fttext_num
            END RECORD
   DEFINE x STRING
   CALL a.clear()
   LET x = "SELECT DISTINCT fttext_ident, ftgroup_ident, fttext_num"
   IF s MATCHES "*fttrans_*" THEN
      LET x = x || " FROM fttext, ftgroup, fttrans"
   ELSE
      LET x = x || " FROM fttext, ftgroup"
   END IF
   LET x = x || " WHERE fttext.fttext_group = ftgroup.ftgroup_num"
   IF s MATCHES "*fttrans_*" THEN
      LET x = x || " AND fttext.fttext_num = fttrans.fttrans_text"
   END IF
   LET x = x || " AND ( " || s || " ) "
   DECLARE c_fttext_query CURSOR FROM x
   FOREACH c_fttext_query INTO r.*
       LET a[a.getLength() + 1].* = r.*
   END FOREACH
   FREE c_fttext_query
END FUNCTION

FUNCTION display_usage()
  DISPLAY "Usage : " || toolname || " [options]"
  DISPLAY "  -V : Display version information."
  DISPLAY "  -h : Display this help."
  DISPLAY "  -db name : Database name."
  DISPLAY "  -un user : Database User name."
  DISPLAY "  -up pswd : Database User password."
  DISPLAY "  -ep : Edit parameters and quit"
  DISPLAY "  -eg : Edit groups and quit"
  DISPLAY "  -el : Edit languages and quit"
  DISPLAY "  -og : Organize messages by groups and quit"
END FUNCTION

FUNCTION show_about()
  CALL __mbox_ok( "About", tooltitle || " " || toolversion, "about")
END FUNCTION

FUNCTION drop_tables()
  WHENEVER ERROR CONTINUE
  DROP TABLE ftparam
  DROP TABLE ftlang
  DROP TABLE ftgroup
  DROP TABLE fttext
  DROP TABLE fttrans
  WHENEVER ERROR STOP
END FUNCTION

FUNCTION check_database()
  DEFINE i, s INTEGER

  WHENEVER ERROR CONTINUE
  LET s = 0
  SELECT COUNT(*) INTO i FROM ftlang
  IF sqlca.sqlcode==0 THEN LET s=s+1 END IF
  SELECT COUNT(*) INTO i FROM ftparam
  IF sqlca.sqlcode==0 THEN LET s=s+1 END IF
  SELECT COUNT(*) INTO i FROM ftlang
  IF sqlca.sqlcode==0 THEN LET s=s+1 END IF
  SELECT COUNT(*) INTO i FROM ftgroup
  IF sqlca.sqlcode==0 THEN LET s=s+1 END IF
  SELECT COUNT(*) INTO i FROM fttext
  IF sqlca.sqlcode==0 THEN LET s=s+1 END IF
  SELECT COUNT(*) INTO i FROM fttrans
  IF sqlca.sqlcode==0 THEN LET s=s+1 END IF
  WHENEVER ERROR STOP
  IF s == 6 THEN
     RETURN TRUE
  END IF
  IF s == 0 THEN
     IF NOT __mbox_yn(tooltitle,
               "Database tables do not exist, do you want to create them?",
               "question") THEN
        RETURN FALSE
     END IF
  ELSE
     IF NOT __mbox_yn(tooltitle,
               "Some database tables exist, but others are missing do you want to re-create them?",
               "question") THEN
        RETURN FALSE
     END IF
     CALL drop_tables()
  END IF

  EXECUTE IMMEDIATE "
  CREATE TABLE ftlang
  (
     ftlang_num INTEGER NOT NULL,
     ftlang_ident VARCHAR(30) NOT NULL UNIQUE,
     ftlang_name VARCHAR(50) NOT NULL UNIQUE,
     ftlang_comment VARCHAR(200),
     PRIMARY KEY (ftlang_num)
  )
  "

  INSERT INTO ftlang VALUES ( 0, '??_??', '<Undefined>', NULL )
  INSERT INTO ftlang VALUES ( 1, 'en_US', 'English (USA) - ASCII', NULL )
  INSERT INTO ftlang VALUES ( 2, 'en_UK', 'English (UK) - ASCII', NULL )
  INSERT INTO ftlang VALUES ( 3, 'fr_FR.utf8', 'French (France) - UTF8', NULL )
  INSERT INTO ftlang VALUES ( 4, 'de_DE.utf8', 'German (Germany) - UTF8', NULL )
  INSERT INTO ftlang VALUES ( 5, 'it_IT.utf8', 'Italian (Italia) - UTF8', NULL )
  INSERT INTO ftlang VALUES ( 6, 'ja_JP.utf8', 'Japanese (Japan) - UTF8', NULL )
  INSERT INTO ftlang VALUES ( 7, 'ko_KR.utf8', 'Korean (Korea) - UTF8', NULL )
  INSERT INTO ftlang VALUES ( 8, 'zh_TW.utf8', 'Traditional Chinese (Taiwan) - UTF8', NULL )
  INSERT INTO ftlang VALUES ( 9, 'zh_CN.utf8', 'Simplified Chinese (PRC) - UTF8', NULL )

  EXECUTE IMMEDIATE "
  CREATE TABLE ftparam
  (
     ftparam_ident VARCHAR(20) NOT NULL,
     ftparam_value VARCHAR(255),
     PRIMARY KEY (ftparam_ident)
  )
  "

  INSERT INTO ftparam VALUES ( 'CURGROUP', '0' ) -- Current group
  INSERT INTO ftparam VALUES ( 'DEVLANG',  '0' ) -- Development language
  INSERT INTO ftparam VALUES ( 'CURLANG',  '0' ) -- Translation language
  INSERT INTO ftparam VALUES ( 'CONFDEL',  'y' ) -- Confirm deletion
  INSERT INTO ftparam VALUES ( 'CONFIMP',  'y' ) -- Confirm import
  INSERT INTO ftparam VALUES ( 'FNFORMAT', '%1.str' ) -- File name format
  INSERT INTO ftparam VALUES ( 'IMPORTDIR', NULL ) -- Import directory
  INSERT INTO ftparam VALUES ( 'EXPORTDIR', '/tmp/%1' ) -- Export directory
  INSERT INTO ftparam VALUES ( 'EXPORTLANG', '1' ) -- Export language
  INSERT INTO ftparam VALUES ( 'IDFILTER', '*' ) -- Filter for text id

  EXECUTE IMMEDIATE "
  CREATE TABLE ftgroup
  (
     ftgroup_num INTEGER NOT NULL,
     ftgroup_ident VARCHAR(50) NOT NULL UNIQUE,
     ftgroup_comment VARCHAR(200),
     PRIMARY KEY (ftgroup_num)
  )
  "

  INSERT INTO ftgroup VALUES ( 0, '<Undefined>', 'No group' )
  INSERT INTO ftgroup VALUES ( 1, 'Common', 'Common texts' )

  EXECUTE IMMEDIATE "
  CREATE TABLE fttext
  (
     fttext_num INTEGER NOT NULL,
     fttext_ident VARCHAR(200) NOT NULL UNIQUE,
     fttext_group INTEGER NOT NULL,
     fttext_locked char(1) NOT NULL,
     PRIMARY KEY (fttext_num),
     FOREIGN KEY (fttext_group) REFERENCES ftgroup(ftgroup_num)
  )
  "

  INSERT INTO fttext VALUES ( 1, 'common.accept', 1, 'n' )
  INSERT INTO fttext VALUES ( 2, 'common.cancel', 1, 'n' )
  INSERT INTO fttext VALUES ( 3, 'common.exit',   1, 'n' )
  INSERT INTO fttext VALUES ( 4, 'common.yes',    1, 'n' )
  INSERT INTO fttext VALUES ( 5, 'common.no',     1, 'n' )
  INSERT INTO fttext VALUES ( 6, 'common.stop',   1, 'n' )

  EXECUTE IMMEDIATE "
  CREATE TABLE fttrans
  (
     fttrans_text INTEGER NOT NULL,
     fttrans_lang INTEGER NOT NULL,
     fttrans_line INTEGER NOT NULL,
     fttrans_value VARCHAR(200),
     PRIMARY KEY (fttrans_text, fttrans_lang, fttrans_line),
     FOREIGN KEY (fttrans_text) REFERENCES fttext(fttext_num),
     FOREIGN KEY (fttrans_lang) REFERENCES ftlang(ftlang_num)
  )
  "

  INSERT INTO fttrans VALUES ( 1, 1, 1, 'Ok' )
  INSERT INTO fttrans VALUES ( 1, 2, 1, 'Accept' )
  INSERT INTO fttrans VALUES ( 1, 3, 1, 'Valider' )

  INSERT INTO fttrans VALUES ( 2, 1, 1, 'Cancel' )
  INSERT INTO fttrans VALUES ( 2, 2, 1, 'Cancel' )
  INSERT INTO fttrans VALUES ( 2, 3, 1, 'Annuler' )

  INSERT INTO fttrans VALUES ( 3, 1, 1, 'Exit' )
  INSERT INTO fttrans VALUES ( 3, 2, 1, 'Quit' )
  INSERT INTO fttrans VALUES ( 3, 3, 1, 'Quitter' )

  INSERT INTO fttrans VALUES ( 4, 1, 1, 'Yes' )
  INSERT INTO fttrans VALUES ( 4, 2, 1, 'Yes' )
  INSERT INTO fttrans VALUES ( 4, 3, 1, 'Oui' )

  INSERT INTO fttrans VALUES ( 5, 1, 1, 'No' )
  INSERT INTO fttrans VALUES ( 5, 2, 1, 'No' )
  INSERT INTO fttrans VALUES ( 5, 3, 1, 'Non' )

  INSERT INTO fttrans VALUES ( 6, 1, 1, 'Stop' )
  INSERT INTO fttrans VALUES ( 6, 2, 1, 'Break' )
  INSERT INTO fttrans VALUES ( 6, 3, 1, 'Stopper' )

  RETURN TRUE

END FUNCTION

--------------------------------------------------------------------------------

FUNCTION fttext_orgfill(idfilter)
  DEFINE idfilter STRING
  DEFINE i INTEGER
  DEFINE s base.StringBuffer
  LET s = base.StringBuffer.create()
  CALL s.append("SELECT fttext_ident, fttext_group, fttext_num, fttext_locked")
  CALL s.append(" FROM fttext")
  IF idfilter IS NOT NULL THEN
     CALL s.append(" WHERE fttext_ident LIKE '")
     CALL s.append(idfilter)
     CALL s.replace("*","%",0)
     CALL s.replace("?","_",0)
     CALL s.append("'")
  END IF
  CALL s.append(" ORDER BY fttext_ident")
  DECLARE c cursor FROM s.toString()
  LET i=0
  CALL txtarr.clear()
  FOREACH c INTO txtrec.*
    LET i=i+1
    LET txtarr[i].* = txtrec.*
  END FOREACH
  RETURN i
END FUNCTION

FUNCTION fttext_organize()
  DEFINE idfilter VARCHAR(100)
  DEFINE x, reload INTEGER
  DEFINE prev_group INTEGER

  LET idfilter = ftparam_get("IDFILTER")
  LET int_flag=FALSE
  LET reload=FALSE

  OPEN WINDOW w_fttext WITH FORM "fgllsm_text" ATTRIBUTES(STYLE="dialog4")

  DIALOG ATTRIBUTES(UNBUFFERED,FIELD ORDER FORM)
      INPUT BY NAME idfilter
      END INPUT

      INPUT ARRAY txtarr FROM sa.*
            ATTRIBUTES(WITHOUT DEFAULTS,
                       INSERT ROW = FALSE, APPEND ROW = FALSE, DELETE ROW = FALSE, AUTO APPEND = FALSE)
         BEFORE FIELD fttext_group
            LET x = DIALOG.getCurrentRow("sa")
            LET prev_group = txtarr[x].fttext_group
         ON CHANGE fttext_group
            LET x = DIALOG.getCurrentRow("sa")
            IF txtarr[x].fttext_locked == 'y' THEN
               IF NOT __mbox_yn(tooltitle,"This text is locked.\n Do you want to unlock?","stop") THEN
                  LET txtarr[x].fttext_group = prev_group
                  NEXT FIELD fttext_group
               END IF
               LET txtarr[x].fttext_locked = "n"
            END IF
            UPDATE fttext SET fttext_group = txtarr[x].fttext_group,
                           fttext_locked = txtarr[x].fttext_locked
              WHERE fttext_num = txtarr[x].fttext_num
         ON CHANGE fttext_locked
            LET x = DIALOG.getCurrentRow("sa")
            UPDATE fttext SET fttext_locked = txtarr[x].fttext_locked
              WHERE fttext_num = txtarr[x].fttext_num
      END INPUT

      BEFORE DIALOG
         LET x = fttext_orgfill(idfilter)
      ON ACTION apply_filter
         LET x = fttext_orgfill(idfilter)
      ON ACTION close
         ACCEPT DIALOG
  END DIALOG

  CLOSE WINDOW w_fttext

  CALL ftparam_set("IDFILTER",idfilter)

  RETURN TRUE

END FUNCTION

