IMPORT FGL util
SCHEMA fglstrmg

DEFINE arr_ftlang DYNAMIC ARRAY OF RECORD LIKE ftlang.*
DEFINE rec_ftlang RECORD
           ident LIKE ftlang.ftlang_ident,
           name LIKE ftlang.ftlang_name,
           comment LIKE ftlang.ftlang_comment
       END RECORD
DEFINE changing SMALLINT

FUNCTION ftlang_edit_setup(d)
  DEFINE d ui.Dialog

  CALL d.setActionActive("dialogtouched", NOT changing)
  CALL d.setActionActive("find", NOT changing)
  CALL d.setActionActive("save", changing)
  CALL d.setActionActive("append", NOT changing)
  CALL d.setActionActive("delete", NOT changing)

END FUNCTION

FUNCTION ftlang_edit()
  DEFINE lr,cr,r INTEGER

  CALL ftlang_getlist(arr_ftlang)
  CALL arr_ftlang.deleteElement(1) -- The 'unknown' group

  OPEN WINDOW w_ftlang WITH FORM "fgllsm_lang" ATTRIBUTE(STYLE='dialog4')

  DIALOG ATTRIBUTES(FIELD ORDER FORM, UNBUFFERED)

     DISPLAY ARRAY arr_ftlang TO sa.*
        BEFORE ROW
           LET cr = DIALOG.getCurrentRow("sa")
           IF ftlang_check_move(DIALOG, lr, cr) THEN
              LET rec_ftlang.ident = arr_ftlang[cr].ftlang_ident
              LET rec_ftlang.name = arr_ftlang[cr].ftlang_name
              LET rec_ftlang.comment = arr_ftlang[cr].ftlang_comment
              CALL ftlang_edit_setup(DIALOG)
           ELSE
              CALL DIALOG.setCurrentRow("sa",lr)
              CONTINUE DIALOG
           END IF
        AFTER ROW 
           LET lr = DIALOG.getCurrentRow("sa")
     END DISPLAY

     INPUT BY NAME rec_ftlang.* ATTRIBUTES(WITHOUT DEFAULTS)
        AFTER FIELD ident
           LET r = ftlang_verify(DIALOG)
     END INPUT

     BEFORE DIALOG
        LET changing = FALSE
        LET lr = DIALOG.getCurrentRow("sa")
        CALL ftlang_edit_setup(DIALOG)

     ON ACTION dialogtouched
        LET changing = TRUE
        CALL ftlang_edit_setup(DIALOG)

     ON ACTION find
        IF NOT ftlang_find(DIALOG) THEN CONTINUE DIALOG END IF

     ON ACTION select
        LET changing = TRUE
        CALL ftlang_edit_setup(DIALOG)
        NEXT FIELD ident

     ON ACTION save
        IF NOT ftlang_save(DIALOG,DIALOG.getCurrentRow("sa")) THEN CONTINUE DIALOG END IF

     ON ACTION append
        IF NOT ftlang_append(DIALOG) THEN CONTINUE DIALOG END IF
        LET lr = DIALOG.getCurrentRow("sa")
        NEXT FIELD ident

     ON ACTION delete
        IF NOT ftlang_delete(DIALOG) THEN CONTINUE DIALOG END IF

     ON ACTION close
        IF changing THEN
           IF NOT __mbox_yn("Languages","Close without saving?","question") THEN
              CONTINUE DIALOG
           END IF
        END IF
        EXIT DIALOG

  END DIALOG

  CLOSE WINDOW w_ftlang

END FUNCTION

FUNCTION ftlang_check_move(d, lr, cr)
  DEFINE d ui.Dialog
  DEFINE lr, cr INTEGER
  DEFINE a CHAR(1)
  DEFINE r SMALLINT

  IF lr==cr OR NOT changing THEN RETURN TRUE END IF

  LET a = __mbox_ync("Languages","Save changes?","stop")
  CASE a
     WHEN "y"
       LET r = ftlang_save(d,lr)
     WHEN "n"
       LET changing = FALSE
       LET r = TRUE
     WHEN "c"
       LET r = FALSE
  END CASE

  RETURN r

END FUNCTION

FUNCTION ftlang_check_changed(d)
  DEFINE d ui.Dialog
  IF changing THEN
     CALL __mbox_ok("Languages","You must first save your changes.","stop")
     RETURN FALSE
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION cmbinit_ftlang(cb)
  DEFINE cb ui.ComboBox
  DEFINE list DYNAMIC ARRAY OF RECORD LIKE ftlang.*
  DEFINE i INTEGER
  CALL ftlang_getlist(list)
  CALL list.deleteElement(1) -- unknown lang
  CALL cb.clear()
  FOR i=1 TO list.getLength()
    CALL cb.addItem(list[i].ftlang_num,list[i].ftlang_ident)
  END FOR
END FUNCTION

FUNCTION ftlang_getlist(list)
  DEFINE list DYNAMIC ARRAY OF RECORD LIKE ftlang.*
  DEFINE rec_ftlang RECORD LIKE ftlang.*
  DECLARE cg_fill CURSOR FOR
    SELECT * FROM ftlang ORDER BY ftlang_num
  CALL list.clear()
  FOREACH cg_fill INTO rec_ftlang.*
    CALL list.appendElement()
    LET list[list.getLength()].* = rec_ftlang.*
  END FOREACH
END FUNCTION

FUNCTION ftlang_getident(num)
  DEFINE num INTEGER
  DEFINE ident LIKE ftlang.ftlang_ident
  SELECT ftlang_ident INTO ident FROM ftlang WHERE ftlang_num=num
  RETURN ident
END FUNCTION

FUNCTION ftlang_exists(ident)
  DEFINE ident LIKE ftlang.ftlang_ident
  DEFINE id INTEGER
  SELECT ftlang_num INTO id FROM ftlang WHERE ftlang_ident=ident
  IF id IS NULL THEN LET id=0 END IF
  RETURN id
END FUNCTION

FUNCTION ftlang_newid()
  DEFINE id INTEGER
  SELECT max(ftlang_num)+1 INTO id FROM ftlang 
  IF id IS NULL THEN LET id=1 END IF
  RETURN id
END FUNCTION

FUNCTION ftlang_select(num)
  DEFINE num INTEGER
  DEFINE rec RECORD LIKE ftlang.*
  SELECT * INTO rec.* FROM ftlang WHERE ftlang_num = num
  RETURN rec.*
END FUNCTION
     
FUNCTION ftlang_find(d)
  DEFINE d ui.Dialog
  DEFINE fs VARCHAR(30)
  DEFINE i,s,c INTEGER
  IF NOT ftlang_check_changed(d) THEN RETURN FALSE END IF
  PROMPT "Enter search string:" FOR fs
  IF int_flag THEN RETURN FALSE END IF
  LET fs=fs||'*'
  LET s = d.getCurrentRow("sa")+1
  LET c = 0
  WHILE c<2
     FOR i=s TO arr_ftlang.getLength()
         IF arr_ftlang[i].ftlang_ident MATCHES fs THEN
            CALL d.setCurrentRow("sa",i) 
            EXIT FOR
         END IF
     END FOR
     LET c = c + 1
     LET s = 1
  END WHILE
  RETURN TRUE
END FUNCTION

FUNCTION ftlang_verify(d)
  DEFINE d ui.Dialog
  IF rec_ftlang.ident MATCHES "* *" THEN
     CALL __mbox_ok("Languages","Identifier must not contain spaces.","stop")
     CALL d.nextField("ident")
     RETURN FALSE
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION ftlang_save(d,row)
  DEFINE d ui.Dialog
  DEFINE r, row INTEGER
  LET r=TRUE
  IF NOT ftlang_verify(d) THEN RETURN FALSE END IF
  WHENEVER ERROR CONTINUE
  UPDATE ftlang SET ftlang_ident = rec_ftlang.ident,
                    ftlang_name = rec_ftlang.name,
                    ftlang_comment = rec_ftlang.comment
         WHERE ftlang_num = arr_ftlang[row].ftlang_num
  WHENEVER ERROR STOP
  IF sqlca.sqlcode THEN
     LET r = FALSE
     CALL __mbox_ok("Update","Could not update the record:\n"||sqlerrmessage,"stop")
  ELSE
     LET changing = FALSE
     LET arr_ftlang[row].ftlang_ident = rec_ftlang.ident
     LET arr_ftlang[row].ftlang_name = rec_ftlang.name
     LET arr_ftlang[row].ftlang_comment = rec_ftlang.comment
     CALL ftlang_edit_setup(d)
  END IF
  RETURN r
END FUNCTION

FUNCTION ftlang_append(d)
  DEFINE d ui.Dialog
  DEFINE rec RECORD LIKE ftlang.*
  DEFINE r, i INTEGER
  IF NOT ftlang_check_changed(d) THEN RETURN FALSE END IF
  CALL d.appendRow("sa")
  LET i = d.getArrayLength("sa")
  LET arr_ftlang[i].ftlang_num = ftlang_newid()
  LET arr_ftlang[i].ftlang_ident = "l_" || arr_ftlang[i].ftlang_num
  LET arr_ftlang[i].ftlang_name = "Language " || arr_ftlang[i].ftlang_num
  LET rec.* = arr_ftlang[i].*
  LET r=TRUE
  WHENEVER ERROR CONTINUE
  INSERT INTO ftlang VALUES ( rec.* )
  WHENEVER ERROR STOP
  IF sqlca.sqlcode THEN
     LET r = FALSE
     CALL __mbox_ok("Insert","Could not insert the record:\n"||sqlerrmessage,"stop")
     CALL d.deleteRow("sa",i)
  ELSE
     CALL d.setCurrentRow("sa",i)
     LET rec_ftlang.ident = arr_ftlang[i].ftlang_ident
     LET rec_ftlang.name = arr_ftlang[i].ftlang_name
     LET rec_ftlang.comment = arr_ftlang[i].ftlang_comment
     LET changing = TRUE
     CALL ftlang_edit_setup(d)
  END IF
  RETURN r
END FUNCTION

FUNCTION ftlang_delete(d)
  DEFINE d ui.Dialog
  DEFINE r,i INTEGER
  LET r=TRUE
  IF NOT __mbox_yn("Delete","Are you sure you want to delete this group?","question") THEN
     RETURN FALSE
  END IF
  LET i = d.getCurrentRow("sa")
  WHENEVER ERROR CONTINUE
  DELETE FROM ftlang WHERE ftlang_num = arr_ftlang[i].ftlang_num
  WHENEVER ERROR STOP
  IF sqlca.sqlcode THEN
     LET r = FALSE
     CALL __mbox_ok("Delete","Could not delete the record:\n"||sqlerrmessage,"stop")
  ELSE
     CALL d.deleteRow("sa",i)
     LET i = d.getCurrentRow("sa")
     IF i == 0 THEN
        LET rec_ftlang.ident = NULL
        LET rec_ftlang.comment = NULL
     ELSE
        LET rec_ftlang.ident = arr_ftlang[i].ftlang_ident
        LET rec_ftlang.comment = arr_ftlang[i].ftlang_comment
     END IF
  END IF
  RETURN r
END FUNCTION

FUNCTION ftlang_getmax()
  DEFINE m INTEGER
  SELECT MAX(ftlang_num) INTO m FROM ftlang
  RETURN m
END FUNCTION

FUNCTION ftlang_getname(num)
  DEFINE num INTEGER
  DEFINE name LIKE ftlang.ftlang_name
  SELECT ftlang_name INTO name FROM ftlang WHERE ftlang_num=num
  RETURN name
END FUNCTION


