New-Item -ItemType Directory -Force output | Out-Null
Get-Content (Get-ChildItem 'sql\migrations\1_migration_latest.sql','sql\stored_procedures\*.sql' -Recurse -File) > output\fullMigrationScipt.sql
Get-Content (Get-ChildItem 'sql\base\*.sql','sql\stored_procedures\*.sql' -Recurse -File) > output\fullEmptyDatabase.sql
Get-Content (Get-ChildItem 'sql\base\*.sql','sql\stored_procedures\*.sql','sql\demo\*.sql' -Recurse -File) > output\fullDemoDatabase.sql
Get-Content (Get-ChildItem 'sql\base\*.sql','sql\stored_procedures\*.sql','sql\offline\central.sql' -Recurse -File) > output\fullOfflineCentralDatabase.sql
Get-Content (Get-ChildItem 'sql\base\*.sql','sql\stored_procedures\*.sql','sql\offline\hf.sql' -Recurse -File) > output\fullOfflineHFDatabase.sql
