$DATABASE = "IMIS"
$USERNAME = ""
$PASSWORD = ""
$OPENIMIS_DATABASE_GIT_FOLDER = ".."
#remove old database
sqlcmd -S 127.0.0.1 -U "$USERNAME" -P "$PASSWORD" -Q "drop database $DATABASE"
#create new database
sqlcmd -S 127.0.0.1 -U "$USERNAME" -P "$PASSWORD" -Q "create database $DATABASE"
#create the structure 
sqlcmd -S 127.0.0.1 -U "$USERNAME" -P "$PASSWORD" -d "$DATABASE" -i "$OPENIMIS_DATABASE_GIT_FOLDER\Empty databases\openIMIS_ONLINE.sql"
#add demo dataset 
sqlcmd -S 127.0.0.1 -U "$USERNAME" -P "$PASSWORD" -d "$DATABASE" -i "$OPENIMIS_DATABASE_GIT_FOLDER\Demo database\openIMIS_demo_ONLINE.sql"



