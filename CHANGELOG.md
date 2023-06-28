## [1.1.3+8]

- Fix migration of new tables in schema.
- Fixed android dbName not working.
- Converted all insert functions to use the ConflictAlgorithm.replace thus performing an upsert.
- Web support is now stable.

## [1.1.0+7]

- Windows and Linux build bug fixes.
- SQLite for web now working. its in development stage.
- How to pass path has changed to facilitate web and windows

## [1.0.6+6]

- Android database error fixed.
- New setup and Release configurations for windows and Linux added to docs.

## [1.0.5+5]

- Fixed an [issue #1](https://github.com/itskenzylimon/quickeydb/issues/1) where `find()` and `findBy({'id' : 'VALUE'})`
  method expected an int primary id.
- Improved documentation on Database relationship.
- Minor improvements.

## [1.0.4+4]

- Find method now accepts both int and String
- Order by accepts a type with `DESC` OR `ASC`
- Cleared warnings and improve package points ratings.

## [1.0.3+3]
- Database `Transaction` - Documentation / Examples
- Database `Batch` - Documentation / Examples
- Updated example project
- `Android`, `IOS`, `Windows` and `Linux` tested and tried.

## [1.0.2+2]
- clear build warnings.
- now using collection and sqflite_common_ffi packages
- Added Code of conducts and Contribution instructions

## [1.0.0+1]

- initial release
- current version (1.0.0+1)