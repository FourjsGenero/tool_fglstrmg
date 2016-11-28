IMPORT FGL fgltfiledlg
SCHEMA fglstrmg

FUNCTION ftparam_edit()
  DEFINE devlang INTEGER
  DEFINE curlang INTEGER
  DEFINE confdel CHAR(1)
  DEFINE confimp CHAR(1)
  DEFINE exportdir STRING
  DEFINE fnformat STRING
  DEFINE tmp STRING
  OPEN WINDOW w_ftparam WITH FORM "fgllsm_param" ATTRIBUTE(STYLE='dialog')
  LET devlang=ftparam_get('DEVLANG')
  LET curlang=ftparam_get('CURLANG')
  LET confdel=ftparam_get('CONFDEL')
  LET confimp=ftparam_get('CONFIMP')
  LET exportdir=ftparam_get('EXPORTDIR')
  LET fnformat=ftparam_get('FNFORMAT')
  LET int_flag=FALSE
  INPUT BY NAME devlang, curlang, confdel, confimp, exportdir, fnformat
        WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED)
     ON ACTION browsefiles
        LET tmp = fglt_file_savedlg(NULL,exportdir,NULL,"DIR","cd,dd,df,sh,oe")
        IF tmp IS NOT NULL THEN
           LET exportdir = tmp
        END IF
     AFTER INPUT
        IF NOT int_flag THEN
           CALL ftparam_set('DEVLANG',devlang)
           CALL ftparam_set('CURLANG',curlang)
           CALL ftparam_set('CONFDEL',confdel)
           CALL ftparam_set('CONFIMP',confimp)
           CALL ftparam_set('EXPORTDIR',exportdir)
           CALL ftparam_set('FNFORMAT',fnformat)
        END IF
  END INPUT
  CLOSE WINDOW w_ftparam
  IF int_flag THEN
     LET int_flag=FALSE
     RETURN FALSE
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION ftparam_get(ident)
  DEFINE ident LIKE ftparam.ftparam_ident
  DEFINE value LIKE ftparam.ftparam_value
  SELECT ftparam_value INTO value FROM ftparam WHERE ftparam_ident=ident
  RETURN value
END FUNCTION

FUNCTION ftparam_set(ident,value)
  DEFINE ident LIKE ftparam.ftparam_ident
  DEFINE value LIKE ftparam.ftparam_value
  DEFINE dummy LIKE ftparam.ftparam_value
  SELECT ftparam_value INTO dummy FROM ftparam WHERE ftparam_ident=ident
  IF sqlca.sqlcode==notfound THEN
    INSERT INTO ftparam VALUES ( ident, value )
  ELSE
    UPDATE ftparam SET ftparam_value = value WHERE ftparam_ident=ident
  END IF
END FUNCTION


