FROM postgres:9.5
ADD 1_acl_database.sql /docker-entrypoint.initdb.d/1_acl_database.sql
ADD 2_functions.sql /docker-entrypoint.initdb.d/2_functions.sql
ADD 3_permissions.sql /docker-entrypoint.initdb.d/3_permissions.sql
