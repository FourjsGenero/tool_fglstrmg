FUNCTION __mbox_ok(title,message,icon)
  DEFINE title, message, icon STRING
  MENU title ATTRIBUTES(STYLE='dialog',IMAGE=icon,COMMENT=message)
     COMMAND "OK"
  END MENU
END FUNCTION

FUNCTION __mbox_yn(title,message,icon)
  DEFINE title, message, icon STRING
  DEFINE r SMALLINT
  MENU title ATTRIBUTES(STYLE='dialog',IMAGE=icon,COMMENT=message)
     COMMAND "Yes" LET r=TRUE
     COMMAND "No"  LET r=FALSE
  END MENU
  RETURN r
END FUNCTION

FUNCTION __mbox_ync(title,message,icon)
  DEFINE title, message, icon STRING
  DEFINE r CHAR
  MENU title ATTRIBUTES(STYLE='dialog',IMAGE=icon,COMMENT=message)
     COMMAND "Yes"     LET r="y"
     COMMAND "No"      LET r="n"
     COMMAND "Cancel"  LET r="c"
  END MENU             
  RETURN r
END FUNCTION
