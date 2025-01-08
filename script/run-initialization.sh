#!/bin/bash


# Wait to be sure that SQL Server came up
sleep 60s

MSSQL_TOOLS_BASE="/opt/mssql-tools"
MSSQL_TOOLS_VERSION=$(ls -d ${MSSQL_TOOLS_BASE}* 2>/dev/null | sort -V | tail -n 1 | sed "s|${MSSQL_TOOLS_BASE}||")
SQLCMD_PATH="${MSSQL_TOOLS_BASE}${MSSQL_TOOLS_VERSION}/bin/sqlcmd"


# DATABASE initialisation

echo "Database initialisation"
# if the table does not exist it will create the table

# get "1" if the database exist : tr get only the integer, cut only the first integer (the second is the number of row affected)
data=$($SQLCMD_PATH -S localhost -U SA -P $SA_PASSWORD -C -Q "SELECT COUNT(*)  FROM master.dbo.sysdatabases WHERE name = N'$DB_NAME'" | tr -dc '0-9'| cut -c1 )
if [[ ${data} -eq "0" ]]; then
        echo 'download full demo database'
        echo 'create database user'
        $SQLCMD_PATH -S localhost -U SA -P $SA_PASSWORD -C -Q "CREATE LOGIN $DB_USER WITH PASSWORD='${SA_PASSWORD}', CHECK_POLICY = OFF"
        echo "merging files"
        ./concatenate_files.sh
        echo 'create database'
        #/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "DROP DATABASE IF EXISTS $DB_NAME"
        $SQLCMD_PATH -S localhost -U SA -P $SA_PASSWORD -C -Q "CREATE DATABASE $DB_NAME"

        if [ "$DEMO_DATASET" ]; then
                /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -i output/fullDemoDatabase.sql -d $DB_NAME | grep . | uniq -c
        else
                $SQLCMD_PATH -S localhost -U SA -P $SA_PASSWORD -C -i output/fullEmptyDatabase.sql -d $DB_NAME | grep . | uniq -c
        fi
        echo ' give to the user the access to the database'
        $SQLCMD_PATH -S localhost -U SA -P $SA_PASSWORD -C -Q  "EXEC sp_changedbowner '$DB_USER'" -d $DB_NAME
else
        echo "database already existing, nothing to do"
fi

# manual cleaning command
# /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "DROP DATABASE $DB_NAME"
# /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "DROP  LOGIN  $DB_USER"
