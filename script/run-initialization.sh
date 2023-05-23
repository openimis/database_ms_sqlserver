#!/bin/bash


# Wait to be sure that SQL Server came up
sleep 60s


# DATABSE initialisation

echo "Database initialisaton"
# if the table does not exsit it will create the table

# get "1" if the database exist : tr get only the integer, cut only the first integer (the second is the number of row affected)
data=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "SELECT COUNT(*)  FROM master.dbo.sysdatabases WHERE name = N'$DB_NAME'" | tr -dc '0-9'| cut -c1 )
if [ ${data} -eq "0" ]; then
        echo 'download full demo database'
        echo 'create database user'
        /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "CREATE LOGIN $DB_USER WITH PASSWORD='${SA_PASSWORD}', CHECK_POLICY = OFF"
        echo "merging files"
        ./concatenate_files.sh
        echo 'create database'
        #/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "DROP DATABASE IF EXISTS $DB_NAME"
        /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "CREATE DATABASE $DB_NAME"

        if [ "$INIT_MODE" = "demo" ]; then
                /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -i output/fullDemoDatabase.sql -d $DB_NAME | grep . | uniq -c
        else
                /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -i output/fullEmptyDatabase.sql -d $DB_NAME | grep . | uniq -c
        fi
        echo ' give to the user the access to the database'
        /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "EXEC sp_changedbowner '$DB_USER'" -d $DB_NAME
else
        echo "database already existing, nothing to do"
fi

# manual cleaning command
# /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "DROP DATABASE $DB_NAME"
# /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "DROP  LOGIN  $DB_USER"
