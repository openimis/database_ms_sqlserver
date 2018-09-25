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

* clone the repository.

```
git clone https://github.com/openimis/database_ms_sqlserver
```

* Restore the openIMIS database backup file (from [Empty databases](./Empty%20databases/) folder) to your SQL Server using SSMS. (The default empty database to restore is openIMIS_ONLINE_vX.Y.Z.bak)

* Once restored, execute the SETUP-IMIS stored procedure.

For documentation purposes only, refer to the plain text scripts of each individual database item in the [Scripts](./Scripts/) folder.

### Upgrading

In order to upgrade from the [previous version of openIMIS database](https://github.com/openimis/master-version/tree/master/Database/Empty%20databases), execute the migration script from [Migration script](./Migration%20script/) folder.

## Deployment

For deployment please read the [installation manual](http://openimis.readthedocs.io/en/latest/web_application_installation.html).

<!--## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.
-->

<!--## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 
-->

<!--## Authors

* **Billie Thompson** - *Initial work* - [PurpleBooth](https://github.com/PurpleBooth)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.
-->

## License

Copyright (c) Swiss Agency for Development and Cooperation (SDC)

This project is licensed under the GNU AGPL v3 License - see the [LICENSE.md](LICENSE.md) file for details.


<!--## Acknowledgments

* Hat tip to anyone whose code was used
* Inspiration
* etc
-->
