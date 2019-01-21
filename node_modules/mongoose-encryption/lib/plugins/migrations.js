'use strict';

var async = require('async');
var _ = require('underscore');
var mongooseEncryption = require('./mongoose-encryption.js');

var VERSION_A_BUF = new Buffer('a');

/**
 * Export For Migrations
 *
 * Should not be used in conjunction with the main encryption plugin.
 */

module.exports = function(schema, options) {
    options.middleware = false; // don't run middleware during the migration
    mongooseEncryption(schema, options); // get all instance methods

    schema.statics.migrateToA = function(cb) {
        this.find({}, function(err, docs){ // find all docs in collection
            if (err) {
                return cb(err);
            }
            async.each(docs, function(doc, errCb){ // for each doc
                if (doc._ac) { // don't migrate if already migrated
                    return errCb();
                }
                if (doc._ct) { // if previously encrypted
                    doc._ct = Buffer.concat([VERSION_A_BUF, doc._ct]); // append version to ciphertext
                    doc.sign(function(err){ // sign
                        if (err) {
                            return errCb(err);
                        }
                        return doc.save(errCb); // save
                    });
                } else { // if not previously encrypted
                    doc.encrypt(function(err){ // encrypt
                        if (err) {
                            return errCb(err);
                        }
                        doc.sign(function(err){ // sign
                            if (err) {
                                return errCb(err);
                            }
                            return doc.save(errCb); // save
                        });
                    });
                }
            }, cb);
        });
    };

    schema.statics.migrateSubDocsToA = function(subDocField, cb) {
        if (typeof subDocField !== 'string'){
            cb(new Error('First argument must be the name of a field in which subdocuments are stored'));
        }
        this.find({}, function(err, docs){ // find all docs in collection
            if (err) {
                return cb(err);
            }
            async.each(docs, function(doc, errCb){ // for each doc
                if (doc[subDocField]) {
                    _.each(doc[subDocField], function(subDoc){ // for each subdoc
                        if (subDoc._ct) { // if previously encrypted
                            subDoc._ct = Buffer.concat([VERSION_A_BUF, subDoc._ct]); // append version to ciphertext
                        }
                    });
                    return doc.save(errCb); // save
                } else {
                    errCb()
                }
            }, cb);
        });
    };


    // sign all the documents in a collection
    schema.statics.signAll = function(cb) {
        this.find({}, function(err, docs){ // find all docs in collection
            if (err) {
                return cb(err);
            }
            async.each(docs, function(doc, errCb){ // for each doc
                doc.sign(function(err){ // sign
                    if (err) {
                        return errCb(err);
                    }
                    doc.save(errCb); // save
                });
            }, cb);
        });
    };
};
