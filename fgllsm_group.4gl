IMPORT FGL util
SCHEMA fglstrmg

DEFINE arr_ftgroup DYNAMIC ARRAY OF RECORD LIKE ftgroup.*
DEFINE rec_ftgroup RECORD
           ident LIKE ftgroup.ftgroup_ident,
           comment LIKE ftgroup.ftgroup_comment
       END RECORD
DEFINE changing SMALLINT

FUNCTION ftgroup_edit_setup(d)
  DEFINE d ui.Dialog

  CALL d.setActionActive("dialogtouched", NOT changing)
  CALL d.setActionActive("find", NOT changing)
  CALL d.setActionActive("save", changing)
  CALL d.setActionActive("append", NOT changing)
  CALL d.setActionActive("delete", NOT changing)

END FUNCTION

FUNCTION ftgroup_edit()
  DEFINE lr,cr,r INTEGER

  CALL ftgroup_getlist(arr_ftgroup)
  CALL arr_ftgroup.deleteElement(1) -- The 'unknown' group

  OPEN WINDOW w_ftgroup WITH FORM "fgllsm_group" ATTRIBUTE(STYLE='dialog4')

  DIALOG ATTRIBUTES(FIELD ORDER FORM, UNBUFFERED)

     DISPLAY ARRAY arr_ftgroup TO sa.*
        BEFORE ROW 
           LET cr = DIALOG.getCurrentRow("sa")
           IF ftgroup_check_move(DIALOG, lr, cr) THEN
              LET rec_ftgroup.ident = arr_ftgroup[cr].ftgroup_ident
              LET rec_ftgroup.comment = arr_ftgroup[cr].ftgroup_comment
              CALL ftgroup_edit_setup(DIALOG)
           ELSE
              CALL DIALOG.setCurrentRow("sa",lr)
              CONTINUE DIALOG
           END IF
        AFTER ROW 
           LET lr = DIALOG.getCurrentRow("sa")
     END DISPLAY

     INPUT BY NAME rec_ftgroup.* ATTRIBUTES(WITHOUT DEFAULTS)
        AFTER FIELD ident
           LET r = ftgroup_verify(DIALOG)
     END INPUT

     BEFORE DIALOG
        LET changing = FALSE
        LET lr = DIALOG.getCurrentRow("sa")
        CALL ftgroup_edit_setup(DIALOG)

     ON ACTION dialogtouched
        LET changing = TRUE
        CALL ftgroup_edit_setup(DIALOG)

     ON ACTION find
        IF NOT ftgroup_find(DIALOG) THEN CONTINUE DIALOG END IF

     ON ACTION select
        LET changing = TRUE
        CALL ftgroup_edit_setup(DIALOG)
        NEXT FIELD ident

     ON ACTION save
        IF NOT ftgroup_save(DIALOG, DIALOG.getCurrentRow("sa")) THEN CONTINUE DIALOG END IF

     ON ACTION append
        IF NOT ftgroup_append(DIALOG) THEN CONTINUE DIALOG END IF
        LET lr = DIALOG.getCurrentRow("sa")
        NEXT FIELD ident

     ON ACTION delete
        IF NOT ftgroup_delete(DIALOG) THEN CONTINUE DIALOG END IF

     ON ACTION close
        IF changing THEN
           IF NOT __mbox_yn("Groups","Close without saving?","question") THEN
              CONTINUE DIALOG
           END IF
        END IF
        EXIT DIALOG

  END DIALOG

  CLOSE WINDOW w_ftgroup

END FUNCTION

FUNCTION ftgroup_check_move(d, lr, cr)
  DEFINE d ui.Dialog
  DEFINE lr, cr INTEGER
  DEFINE a CHAR(1)
  DEFINE r SMALLINT

  IF lr==cr OR NOT changing THEN RETURN TRUE END IF

  LET a = __mbox_ync("Groups","Save changes?","stop")
  CASE a
     WHEN "y"
       LET r = ftgroup_save(d,lr)
     WHEN "n"
       LET changing = FALSE
       LET r = TRUE
     WHEN "c"
       LET r = FALSE
  END CASE

  RETURN r

END FUNCTION

FUNCTION ftgroup_check_changed(d)
  DEFINE d ui.Dialog
  LET d = NULL
  IF changing THEN
     CALL __mbox_ok("Groups","You must first save your changes.","stop")
     RETURN FALSE
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION cmbinit_ftgroup(cb)
  DEFINE cb ui.ComboBox
  DEFINE list DYNAMIC ARRAY OF RECORD LIKE ftgroup.*
  DEFINE i INTEGER
  CALL ftgroup_getlist(list)
  CALL list.deleteElement(1) -- unknown lang
  CALL cb.clear()
  FOR i=1 TO list.getLength()
    CALL cb.addItem(list[i].ftgroup_num,list[i].ftgroup_ident)
  END FOR
END FUNCTION

FUNCTION ftgroup_getlist(list)
  DEFINE list DYNAMIC ARRAY OF RECORD LIKE ftgroup.*
  DEFINE rec_ftgroup RECORD LIKE ftgroup.*
  DECLARE cg_fill CURSOR FOR
    SELECT * FROM ftgroup ORDER BY ftgroup_num
  CALL list.clear()
  FOREACH cg_fill INTO rec_ftgroup.*
    CALL list.appendElement()
    LET list[list.getLength()].* = rec_ftgroup.*
  END FOREACH
END FUNCTION

FUNCTION ftgroup_getident(num)
  DEFINE num INTEGER
  DEFINE ident LIKE ftgroup.ftgroup_ident
  SELECT ftgroup_ident INTO ident FROM ftgroup WHERE ftgroup_num=num
  RETURN ident
END FUNCTION

FUNCTION ftgroup_exists(ident)
  DEFINE ident LIKE ftgroup.ftgroup_ident
  DEFINE id INTEGER
  SELECT ftgroup_num INTO id FROM ftgroup WHERE ftgroup_ident=ident
  IF id IS NULL THEN LET id=0 END IF
  RETURN id
END FUNCTION

FUNCTION ftgroup_newid()
  DEFINE id INTEGER
  SELECT max(ftgroup_num)+1 INTO id FROM ftgroup 
  IF id IS NULL THEN LET id=1 END IF
  RETURN id
END FUNCTION

FUNCTION ftgroup_select(num)
  DEFINE num INTEGER
  DEFINE rec RECORD LIKE ftgroup.*
  SELECT * INTO rec.* FROM ftgroup WHERE ftgroup_num = num
  RETURN rec.*
END FUNCTION
     
FUNCTION ftgroup_find(d)
  DEFINE d ui.Dialog
  DEFINE fs VARCHAR(30)
  DEFINE i,s,c INTEGER
  IF NOT ftgroup_check_changed(d) THEN RETURN FALSE END IF
  PROMPT "Enter search string:" FOR fs
  IF int_flag THEN RETURN FALSE END IF
  LET fs=fs||'*'
  LET s = d.getCurrentRow("sa")+1
  LET c = 0
  WHILE c<2
     FOR i=s TO arr_ftgroup.getLength()
         IF arr_ftgroup[i].ftgroup_ident MATCHES fs THEN
            CALL d.setCurrentRow("sa",i) 
            EXIT FOR
         END IF
     END FOR
     LET c = c + 1
     LET s = 1
  END WHILE
  RETURN TRUE
END FUNCTION

FUNCTION ftgroup_verify(d)
  DEFINE d ui.Dialog
  IF rec_ftgroup.ident MATCHES "* *" THEN
     CALL __mbox_ok("Groups","Identifier must not contain spaces.","stop")
     CALL d.nextField("ident")
     RETURN FALSE
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION ftgroup_save(d,row)
  DEFINE d ui.Dialog
  DEFINE r, row INTEGER
  LET r=TRUE
  IF NOT ftgroup_verify(d) THEN RETURN FALSE END IF
  WHENEVER ERROR CONTINUE
  UPDATE ftgroup SET ftgroup_ident = rec_ftgroup.ident,
                     ftgroup_comment = rec_ftgroup.comment
         WHERE ftgroup_num = arr_ftgroup[row].ftgroup_num
  WHENEVER ERROR STOP
  IF sqlca.sqlcode THEN
     LET r = FALSE
     CALL __mbox_ok("Update","Could not update the record:\n"||sqlerrmessage,"stop")
  ELSE
     LET changing = FALSE
     LET arr_ftgroup[row].ftgroup_ident = rec_ftgroup.ident
     LET arr_ftgroup[row].ftgroup_comment = rec_ftgroup.comment
     CALL ftgroup_edit_setup(d)
  END IF
  RETURN r
END FUNCTION

FUNCTION ftgroup_append(d)
  DEFINE d ui.Dialog
  DEFINE rec RECORD LIKE ftgroup.*
  DEFINE r, i INTEGER
  IF NOT ftgroup_check_changed(d) THEN RETURN FALSE END IF
  CALL d.appendRow("sa")
  LET i = d.getArrayLength("sa")
  LET arr_ftgroup[i].ftgroup_num = ftgroup_newid()
  LET arr_ftgroup[i].ftgroup_ident = "group_" || arr_ftgroup[i].ftgroup_num
  LET rec.* = arr_ftgroup[i].*
  LET r=TRUE
  WHENEVER ERROR CONTINUE
  INSERT INTO ftgroup VALUES ( rec.* )
  WHENEVER ERROR STOP
  IF sqlca.sqlcode THEN
     LET r = FALSE
     CALL __mbox_ok("Insert","Could not insert the record:\n"||sqlerrmessage,"stop")
     CALL d.deleteRow("sa", d.getArrayLength("sa"))
  ELSE
     CALL d.setCurrentRow("sa",i)
     LET rec_ftgroup.ident = arr_ftgroup[i].ftgroup_ident
     LET rec_ftgroup.comment = arr_ftgroup[i].ftgroup_comment
     LET changing = TRUE
     CALL ftgroup_edit_setup(d)
  END IF
  RETURN r
END FUNCTION

FUNCTION ftgroup_delete(d)
  DEFINE d ui.Dialog
  DEFINE r,i INTEGER
  LET r=TRUE
  IF NOT __mbox_yn("Delete","Are you sure you want to delete this group?","question") THEN
     RETURN FALSE
  END IF
  LET i = d.getCurrentRow("sa")
  WHENEVER ERROR CONTINUE
  DELETE FROM ftgroup WHERE ftgroup_num = arr_ftgroup[i].ftgroup_num
  WHENEVER ERROR STOP
  IF sqlca.sqlcode THEN
     LET r = FALSE
     CALL __mbox_ok("Delete","Could not delete the record:\n"||sqlerrmessage,"stop")
  ELSE
     CALL d.deleteRow("sa",i)
     LET i = d.getCurrentRow("sa")
     IF i == 0 THEN
        LET rec_ftgroup.ident = NULL
        LET rec_ftgroup.comment = NULL
     ELSE
        LET rec_ftgroup.ident = arr_ftgroup[i].ftgroup_ident
        LET rec_ftgroup.comment = arr_ftgroup[i].ftgroup_comment
     END IF
  END IF
  RETURN r
END FUNCTION

FUNCTION ftgroup_create(aname)
  DEFINE aname STRING
  DEFINE num LIKE ftgroup.ftgroup_num
  DEFINE ident LIKE ftgroup.ftgroup_ident
  LET num = ftgroup_newid()
  IF aname IS NULL THEN
     LET ident = "group_"|| num
  ELSE
     LET ident = aname
  END IF
  WHENEVER ERROR CONTINUE
  INSERT INTO ftgroup VALUES ( num, ident, null )
  WHENEVER ERROR STOP
  IF sqlca.sqlcode THEN
     RETURN -1, null
  END IF
  RETURN num, ident
END FUNCTION

