Description: Fix various lintian errors relating to man pages, including line breaks, non-standard FHS paths, etc.
Author: Bill Blough <devel@blough.us>

Index: amanda.git/common-src/conffile.c
===================================================================
--- amanda.git.orig/common-src/conffile.c	2017-12-15 15:45:23.338017573 +0000
+++ amanda.git/common-src/conffile.c	2017-12-15 15:45:23.334017570 +0000
@@ -6422,9 +6422,9 @@ init_defaults(
     conf_init_str(&conf_data[CNF_CHANGERFILE]             , "changer");
     conf_init_str   (&conf_data[CNF_TAPELIST]             , "tapelist");
     conf_init_str   (&conf_data[CNF_DISKFILE]             , "disklist");
-    conf_init_str   (&conf_data[CNF_INFOFILE]             , "/usr/adm/amanda/curinfo");
-    conf_init_str   (&conf_data[CNF_LOGDIR]               , "/usr/adm/amanda");
-    conf_init_str   (&conf_data[CNF_INDEXDIR]             , "/usr/adm/amanda/index");
+    conf_init_str   (&conf_data[CNF_INFOFILE]             , CONFIG_DIR "/curinfo");
+    conf_init_str   (&conf_data[CNF_LOGDIR]               , CONFIG_DIR);
+    conf_init_str   (&conf_data[CNF_INDEXDIR]             , CONFIG_DIR "/index");
     conf_init_ident    (&conf_data[CNF_TAPETYPE]             , "DEFAULT_TAPE");
     conf_init_identlist(&conf_data[CNF_HOLDINGDISK]          , NULL);
     conf_init_int      (&conf_data[CNF_DUMPCYCLE]            , CONF_UNIT_NONE, 10);
