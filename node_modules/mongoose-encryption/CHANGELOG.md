# Release Notes

## v.2.0.1
2018-7-30
- Upgrade dependencies

## v.2.0.0
2018-7-30
- Support Mongoose 5 #70 #71 #75 #79
- Drop support for Mongoose 3 & 4

## v.1.5.0
2017-3-18
- Support `SingleNested` document as of mongoose 4.8.0 #50

## v.1.4.0
2016-12-5
- Throw error when plugin added twice, or migrations added alongside standard plugin. #42
- Move underscore to dependencies #46

## v.1.3.2
2016-10-24
- Move mpath to dependencies #44

# v.1.3.1
2016-5-24
- Allow wider range of underscore versions

## v.1.3.0
2015-12-13
- Add support for addressing nested fields in options using dot notation

## v.1.2.3
2015-11-29
- Change Mongoose to peer dependency
- Check for compatibility with Node and Mongoose versions

## v.1.2.2
2015-11-4
- Fix buffer handling for Node 4.x compatibility

## v.1.2.1
2015-8-31
- Fix authentication when adding or removing a child from a subcollection

## v.1.2.0
2015-08-16
- Update tests to be Mongoose 4.x compatible
- Fix decryption of buffers to be Node 0.12.x compatible
- Cleaner documents after `.authenticate` and `.save`

## v 1.1.0
2015-05-13
- Force "transactions" across authenticated fields

## v 1.0.1
2015-03-16
- Change repo location
- Update readme
- No code changes

## v 1.0.0
2015-03-03
- API declared stable
- No code changes

## v 0.13.0
2015-02-21
- Add `decryptPostSave` option
- Implement basic support for nested schemas

## v 0.12.0
2015-02-14
- Add authentication
	- Provides defense against attackers with write access
	- Add `signingKey` option
	- Add `secret` option
    - Rename `key` -> `encryptionKey`
    - Rename `fields` -> `encryptedFields`
    - Rename `exclude` -> `excludeFromEncryption`
	- Add `additionalAuthenticatedFields` option
- Prepend version number to ciphertext and authentication code to allow for version detection
	- Makes any future migrations safer and potentially allows them to be done in stages
	- Requires migration to upgrade from previous versions
		- If you have encrypted subdocuments, first run the class method `migrateSubDocsToA()` on the parent collection
        - Then run the class method `migrateToA()` on any encrypted collections (that are not themselves subdocuments)
