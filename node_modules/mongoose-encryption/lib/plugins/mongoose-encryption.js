'use strict';

var crypto = require('crypto');
var _ = require('underscore');
var mongoose = require('mongoose');
var stableStringify = require('json-stable-stringify');
var async = require('async');
var dotty = require('dotty');
var bufferEqual = require('buffer-equal-constant-time');
var mpath = require('mpath');
var semver = require('semver');

var objectUtil = require('../util/object-util.js');
var cryptoUtil = require('../util/crypto-util.js');
var decryptEmbeddedDocs = require('../util/decryptEmbeddedDocs.js');

var pick = objectUtil.pick;
var setFieldValue = objectUtil.setFieldValue;
var isEmbeddedDocument = objectUtil.isEmbeddedDocument;
var drop256 = cryptoUtil.drop256;
var deriveKey = cryptoUtil.deriveKey;

/**  Plugin Constants */

var VERSION = 'a';

var ENCRYPTION_ALGORITHM = 'aes-256-cbc';
var IV_LENGTH = 16;
var AAC_LENGTH = 32;
var VERSION_LENGTH = 1;
var VERSION_BUF = new Buffer(VERSION);


if(semver.lt(mongoose.version, '5.0.0')){
    throw new Error('Mongoose version 5.0.0 or greater is required');
}

/**
 * Mongoose encryption plugin
 * @module mongoose-encryption
 *
 *
 * @param      {Object}     schema   The schema
 * @param      {Object}     options  Plugin options
 * @param      {string}     [options.secret]  A secret string which will be used to generate an encryption key and a signing key
 * @param      {string}     [options.encryptionKey]  A secret string which will be used to generate an encryption key
 * @param      {string}     [options.signingKey]  A secret string which will be used to generate a signing key
 * @param      {string[]}   [options.encryptedFields]  A list of fields to encrypt. Default is to encrypt all fields.
 * @param      {string[]}   [options.excludeFromEncryption]  A list of fields to not encrypt
 * @param      {string[]}   [options.additionalAuthenticatedFields]  A list of fields to authenticate even if they aren't encrypted
 * @param      {boolean}    [options.requireAuthenticationCode=true]  Whether documents without an authentication code are valid
 * @param      {boolean}    [options.decryptPostSave=true]  Whether to automatically decrypt documents in the application after saving them (faster if false)
 * @param      {string}     [options.collectionId]  If you update the Model name of the schema, this should be set to its original name
 * @return     {undefined}
 */

var mongooseEncryption = function(schema, options) {
    var encryptedFields, excludedFields, authenticatedFields, encryptionKey, signingKey, path;

    _.defaults(options, {
        middleware: true, // allow for skipping middleware with false
        requireAuthenticationCode: true, // allow for no authentication code on docs (not recommended),
        decryptPostSave: true, // allow for skipping the decryption after save for improved performance
        _suppressDuplicatePluginError: false // used for testing only

    });

    /** Encryption Keys */

    if (options.secret) {
        if (options.encryptionKey || options.signingKey) {
            throw new Error('if options.secret is used, then options.encryptionKey and options.signingKey must not be included');
        } else {
            encryptionKey = drop256(deriveKey(options.secret, 'enc'));
            signingKey = deriveKey(options.secret, 'sig');
        }
    } else {
        if (!options.encryptionKey || !options.signingKey) {
            throw new Error('must provide either options.secret or both options.encryptionKey and options.signingKey');
        } else {
            encryptionKey = new Buffer(options.encryptionKey, 'base64');
            if (encryptionKey.length !== 32) {
                throw new Error('options.encryptionKey must be a a 32 byte base64 string');
            }
            signingKey = new Buffer(options.signingKey, 'base64');
            if (signingKey.length !== 64) {
                throw new Error('options.signingKey must be a a 64 byte base64 string');
            }
        }
    }


    /** Deprecated options */

    if (options.fields) {
        options.encryptedFields = options.fields;
        console.warn('options.fields has been deprecated. please use options.encryptedFields');
    }
    if (options.exclude) {
        options.excludeFromEncryption = options.exclude;
        console.warn('options.fields has been deprecated. please use options.excludeFromEncryption');
    }


    /** Encryption Options */

    if (options.encryptedFields) {
        encryptedFields = _.difference(options.encryptedFields, ['_ct']);
    } else {
        excludedFields = _.union(['_id', '_ct'], options.excludeFromEncryption);
        encryptedFields = _.chain(schema.paths)
            .filter(function(pathDetails) { // exclude indexed fields
                return !pathDetails._index
            })
            .pluck('path') // get path name
            .difference(excludedFields) // exclude excluded fields
            .uniq()
            .value();
    }


    /** Authentication Options */

    var baselineAuthenticateFields = ['_id', '_ct'];

    if (options.additionalAuthenticatedFields) {
        authenticatedFields = _.union(options.additionalAuthenticatedFields, baselineAuthenticateFields);
    } else {
        authenticatedFields = baselineAuthenticateFields;
    }




    /** Augment Schema */

    if (!schema.paths._ct) { // ciphertext
        schema.add({
            _ct: {
                type: Buffer
            }
        });
    }
    if (!schema.paths._ac) { // authentication code
        schema.add({
            _ac: {
                type: Buffer
            }
        });
    }



    /** Authentication Functions */

    var computeAC = function(doc, fields, version, modelName) {
        // HMAC-SHA512-drop-256
        var hmac = crypto.createHmac('sha512', signingKey);

        if (!(fields instanceof Array)){
            throw new Error('fields must be an array');
        }
        if (fields.indexOf('_id') === -1) {
            throw new Error('_id must be in array of fields to authenticate');
        }
        if (fields.indexOf('_ac') !== -1) {
            throw new Error('_ac cannot be in array of fields to authenticate');
        }

        var collectionId = options.collectionId || modelName || doc.constructor.modelName;

        if (!collectionId) {
            throw new Error('For authentication, each collection must have a unique id. This is normally the model name when there is one, but can be overridden or added by options.collectionId');
        }

        // convert to regular object if possible in order to convert to the eventual mongo form which may be different than mongoose form
        // and only pick fields that will be authenticated
        var objectToAuthenticate = pick((doc.toObject ? doc.toObject() : doc), fields);
        var stringToAuthenticate = stableStringify(objectToAuthenticate);
        hmac.update(collectionId);
        hmac.update(version);
        hmac.update(stringToAuthenticate);
        hmac.update(JSON.stringify(fields));
        var fullAuthenticationBuffer = new Buffer(hmac.digest());
        return drop256(fullAuthenticationBuffer);
    };

    /** Functions To Check If Authenticated Fields Were Selected By Query */

    var authenticationFieldsToCheck = _.chain(authenticatedFields).union(['_ac']).without('_id').value(); // _id is implicitly selected

    var authenticatedFieldsIsSelected = function(doc){
        return _.map(authenticationFieldsToCheck, function(field) {
            return doc.isSelected(field);
        });
    };

    var allAuthenticationFieldsSelected = function(doc){
        var isSelected = authenticatedFieldsIsSelected(doc);
        if (_.uniq(isSelected).length === 1){
            return isSelected[0];
        } else {
            return false;
        }
    };

    var noAuthenticationFieldsSelected = function(doc){
        var isSelected = authenticatedFieldsIsSelected(doc);
        if (_.uniq(isSelected).length === 1){
            return isSelected[0] === false;
        } else {
            return false;
        }
    };

    /** Ensure plugin only added once per schema */
    if(schema.statics._mongooseEncryptionInstalled){
        if(!options._suppressDuplicatePluginError){
            throw new Error(
                'Mongoose encryption plugin can only be added once per schema.\n\n' +
                'If you are running migrations, please remove encryption middleware first. ' +
                'Migrations should be run in a script where `encrypt.migrations` is added to the schema, '+
                'however the standard `encrypt` middleware should not be present at the same time. '
            );
        }

    } else {
        schema.statics._mongooseEncryptionInstalled = true;
    }

    /** Middleware */

    if (options.middleware) { // defaults to true
        schema.pre('init', function(data) {
            var err = null;
            try { // this hook must be synchronous for embedded docs, so everything is synchronous for code simplicity
                if (!isEmbeddedDocument(this)){ // don't authenticate embedded docs because there's no way to handle the error appropriately
                    if (allAuthenticationFieldsSelected(this)) {
                        this.authenticateSync.call(data, this.constructor.modelName);
                    } else {
                        if (!noAuthenticationFieldsSelected(this)){
                            throw new Error("Authentication failed: Only some authenticated fields were selected by the query. Either all or none of the authenticated fields (" + authenticationFieldsToCheck + ") should be selected for proper authentication.");
                        }
                    }
                }
                if (this.isSelected('_ct')){
                    this.decryptSync.call(data);
                }
            } catch (e) {
                err = e;
            }

            if (isEmbeddedDocument(this)) {
                if (err) {
                    console.error(err);
                    throw err; // note: this won't actually get thrown until save, because errors in subdoc init fns are CastErrors and aren't thrown by validate()
                }
                this._doc = data;
                return this;
            } else {
                if (err) throw err;
            }
        });

        schema.pre('save', function(next) {
            var that = this;
            if (this.isNew || this.isSelected('_ct') ){
                that.encrypt(function(err){
                    if (err) {
                        next(err);
                    } else {
                        if ((that.isNew || allAuthenticationFieldsSelected(that)) && !isEmbeddedDocument(that)) {
                            _.forEach(authenticatedFields, function(authenticatedField){
                                that.markModified(authenticatedField)
                            });

                            that.sign(next);
                        } else {
                            next();
                        }
                    }
                });
            } else if (allAuthenticationFieldsSelected(this) && !isEmbeddedDocument(this)) { // _ct is not selected but all authenticated fields are. cannot get hit in current version.
                _.forEach(authenticatedFields, function(authenticatedField){
                    that.markModified(authenticatedField)
                });

                this.sign(next);
            } else {
                next();
            }
        });


        if (options.decryptPostSave) { // true by default
            schema.post('save', function(doc) {
                if (isEmbeddedDocument(doc)) {
                    return doc;
                }

                if (_.isFunction(doc.decryptSync)) {
                    doc.decryptSync();
                }

                decryptEmbeddedDocs(doc);

                return doc;
            });
        }
    }



    /** Encryption Instance Methods */

    schema.methods.encrypt = function(cb) {
        var that = this;

        if(this._ct){
            return cb(new Error('Encrypt failed: document already contains ciphertext'));
        }

        // generate random iv
        crypto.randomBytes(IV_LENGTH, function(err, iv) {
            var cipher, jsonToEncrypt, objectToEncrypt;
            if (err) {
                return cb(err);
            }
            cipher = crypto.createCipheriv(ENCRYPTION_ALGORITHM, encryptionKey, iv);
            objectToEncrypt = pick(that, encryptedFields, {excludeUndefinedValues: true});

            jsonToEncrypt = JSON.stringify(objectToEncrypt);

            cipher.end(jsonToEncrypt, 'utf-8', function() {
                // add ciphertext to document
                that._ct = Buffer.concat([VERSION_BUF, iv, cipher.read()]);

                // remove encrypted fields from cleartext
                encryptedFields.forEach(function(field){
                    setFieldValue(that, field, undefined);
                });

                cb(null);
            });
        });
    };

    schema.methods.decrypt = function(cb) { // callback style but actually synchronous to allow for decryptSync without copypasta or complication
        try {
            schema.methods.decryptSync.call(this);
        } catch(e){
            return cb(e);
        }
        cb();
    };

    schema.methods.decryptSync = function() {
        var that = this;
        var ct, ctWithIV, decipher, iv, idString, decryptedObject, decryptedObjectJSON, decipheredVal;
        if (this._ct) {
            ctWithIV = this._ct.hasOwnProperty('buffer') ? this._ct.buffer : this._ct;
            iv = ctWithIV.slice(VERSION_LENGTH, VERSION_LENGTH + IV_LENGTH);
            ct = ctWithIV.slice(VERSION_LENGTH + IV_LENGTH, ctWithIV.length);

            decipher = crypto.createDecipheriv(ENCRYPTION_ALGORITHM, encryptionKey, iv);
            try {
                decryptedObjectJSON = decipher.update(ct, undefined, 'utf8') + decipher.final('utf8');
                decryptedObject = JSON.parse(decryptedObjectJSON);
            } catch (err) {
                if (this._id) {
                    idString = this._id.toString();
                } else {
                    idString = 'unknown';
                }
                throw new Error('Error parsing JSON during decrypt of ' + idString + ': ' + err);
            }

            encryptedFields.forEach(function(field) {
                decipheredVal = mpath.get(field, decryptedObject);

                //JSON.parse returns {type: "Buffer", data: Buffer} for Buffers
                //https://nodejs.org/api/buffer.html#buffer_buf_tojson
                if(_.isObject(decipheredVal) && decipheredVal.type === "Buffer"){
                    setFieldValue(that, field, decipheredVal.data);
                }else {
                    setFieldValue(that, field, decipheredVal);
                }
            });

            this._ct = undefined;
            this._ac = undefined;
        }
    };




    /** Authentication Instance Methods */

    schema.methods.sign = function(cb) {
        var basicAC = computeAC(this, authenticatedFields, VERSION);
        var authenticatedFieldsBuf = new Buffer(JSON.stringify(authenticatedFields));
        this._ac = Buffer.concat([VERSION_BUF, basicAC, authenticatedFieldsBuf]);
        cb();
    };

    schema.methods.authenticate = function(cb) { // callback style but actually synchronous to allow for decryptSync without copypasta or complication
        try {
            schema.methods.authenticateSync.call(this);
        } catch(e){
            return cb(e);
        }
        cb();
    };

    schema.methods.authenticateSync = function() {
        if (!this._ac) {
            if (options.requireAuthenticationCode) {
                throw new Error('Authentication code missing');
            } else {
                return null;
            }
        }
        var acBuf = this._ac.hasOwnProperty('buffer') ? this._ac.buffer : this._ac;
        if (acBuf.length < VERSION_LENGTH + AAC_LENGTH + 2) {
            throw new Error('_ac is too short and has likely been cut off or modified');
        }
        var versionUsed = acBuf.slice(0, VERSION_LENGTH).toString();
        var basicAC = acBuf.slice(VERSION_LENGTH, VERSION_LENGTH + AAC_LENGTH);
        var authenticatedFieldsUsed = JSON.parse(acBuf.slice(VERSION_LENGTH + AAC_LENGTH, acBuf.length).toString());

        var expectedHMAC = computeAC(this, authenticatedFieldsUsed, versionUsed, arguments[0]); // pass in modelName as argument in init hook

        var authentic = bufferEqual(basicAC, expectedHMAC);
        if (!authentic){
            throw new Error('Authentication failed');
        }
    };
};


module.exports = mongooseEncryption;

// Exports For Tests //
module.exports.AAC_LENGTH = AAC_LENGTH;
module.exports.VERSION_LENGTH = VERSION_LENGTH;
