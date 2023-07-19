[![Automated CI testing](https://github.com/openimis/database_ms_sqlserver/actions/workflows/openmis-module-test.yml/badge.svg?branch=develop)](https://github.com/openimis/database_ms_sqlserver/actions/workflows/openmis-module-test.yml)
# openIMIS SQL Server database

This repository contains the openIMIS database for Microsoft SQL Server.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

In order to use and develop the openIMIS database on your local machine, you first need to install:

* Microsoft SQL Server (minimum version 2012)
* Microsoft SQL Server Management Studio (SSMS)

### Installation

To make a copy of this project on your local machine, please follow the next steps:

* clone the repository

```
git clone https://github.com/openimis/database_ms_sqlserver
```

* create a new database (i.e. openIMIS.X.Y.Z where X.Y.Z is the openIMIS database version)

* Execute the initial database creation script; FullEmpytDatabase.sql or fullDemoDatabase.sql, see "creating SQL script" to get it

### Upgrading

In order to upgrade from the previous version of openIMIS database (see [Versioning](#versioning) section), execute the migration script (fullMigrationSript), see "creating SQL script" to get it

## Deployment

For deployment please read the [installation manual](http://openimis.readthedocs.io/en/latest/web_application_installation.html).

<!--## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.
-->

### creating SQL script 

 SQL files for initialisaiton or update are created using bash script concatenate_files.sh or by downloading the sql-file zip from the latest release https://github.com/openimis/database_ms_sqlserver/releases/latest 

## openIMIS dockerized database



| :bomb: Disclaimer : NOT FOR PRODUCTION USE :bomb: |
| --- |
| This repository provides a dockerized openIMIS database. It provides a quick setup for development, testing or demoing. ***It is NOT INTENDED FOR PRODUCTION USE.*** |


### ENV

- INIT_MODE if set to demo will init the database to demo (works only if not yet init)
- SQL_SCRIPT_URL url to init scripts
- **ACCEPT_EULA** must be set to Y to accept MS SQL EULA
- SA_PASSWORD default: IMISuserP@s
- DB_USER_PASSWORD defautl: IMISuserP@s
- DB_NAMEdefautl: IMIS
- DB_USER defautl: IMISUser


### gettingstarted

Please look for the directions on the openIMIS Wiki: https://openimis.atlassian.net/wiki/spaces/OP/pages/963182705/MO1.1+Install+the+modular+openIMIS+using+Docker

Using the provided docker file, you can build a docker image running a SQL Server 2017, with a restored openIMIS backup database.
This is done by giving the following ARGs to the docker build command:
```
docker build \
  --build-arg ACCEPT_EULA=Y \
  --build-arg SA_PASSWORD=<your secret password> \
  . \
  -t openimis-db
```

optinnaly 
```
--build-arg SQL_SCRIPT_URL=<url to the sql script to create the database> \
  --build-arg DB_USER_PASSWORD=StrongPassword
  --build-arg DB_USER=IMISUser
  --build-arg DB_NAME=IMIS
```
***Notes***:
* by setting the ACCEPT_EULA=Y, you explicitely accept [Microsoft EULA](https://go.microsoft.com/fwlink/?linkid=857698) for the dockerized SQL Server 2017. Please ensure you read it and use the provided software according to the terms of that license.
* choose a strong password (at least 8 chars,...)... or SQL Server will complain


To start the image in a docker container: `docker run -p 1433:1433 openimis-db`
To restore the backup inside the container:
* To spot the ID of the container: `docker container ls` (spot the row with openimis-db IMAGE name)


***Note:***
the container will check if the database exist, if it doesnot it will take the latest demo release version and deploy it , SQL_SCRIPT_URL is per defautl set to "https://github.com/openimis/database_ms_sqlserver/releases/latest/download/sql-files.zip"
to have data retention when container are recreated volums need to be configured as microsoft docs suggest
* <host directory>/data:/var/opt/mssql/data : database files
* <host directory>/log:/var/opt/mssql/log : logs files
* <host directory>/secrets:/var/opt/mssql/secrets : secrets

The database is writen within the container. If you want to keep your data between container execution, stop/start the container via `docker stop <CONTAINER ID>` / `docker start <CONTAINER ID>` (using `docker run ... ` recreates a new container from the image... thus without any data)



## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/openimis/web_app_vb/tags). 

## Issues

To report a bug, request a new features or asking questions about openIMIS, please use the [openIMIS Service Desk](https://openimis.atlassian.net/servicedesk/customer/portal/1). 

## License

Copyright (c) Swiss Agency for Development and Cooperation (SDC)

This project is licensed under the GNU AGPL v3 License - see the [LICENSE.md](LICENSE.md) file for details.

