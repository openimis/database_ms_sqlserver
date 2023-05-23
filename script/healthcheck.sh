#!/usr/bin/env bash
data=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $SA_PASSWORD -Q "SELECT COUNT(*)  FROM master.dbo.sysdatabases WHERE name = N'$DB_NAME'" | tr -dc '0-9'| cut -c1 )
if [ ${data} -eq "1" ]; then
    exit 0
else
    exit 1
fi