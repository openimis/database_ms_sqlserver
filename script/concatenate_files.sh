#!/bin/bash

mkdir output
cat sql/migrations/1_migration_latest.sql sql/stored_procedures/*.sql > output/fullMigrationScript.sql
cat sql/base/*.sql sql/stored_procedures/*.sql > output/fullEmptyDatabase.sql
cat sql/base/*.sql sql/stored_procedures/*.sql sql/demo/*.sql > output/fullDemoDatabase.sql
cat sql/demo/*.sql > output/DemoDataset.sql
cat sql/base/*.sql sql/stored_procedures/*.sql sql/offline/central.sql > output/fullOfflineCentralDatabase.sql
cat sql/base/*.sql sql/stored_procedures/*.sql sql/offline/hf.sql > output/fullOfflineHFDatabase.sql
