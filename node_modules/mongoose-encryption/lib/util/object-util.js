'use strict';
var _ = require('underscore');
var mpath = require('mpath');


/**
 * Sets the value of a field.
 *
 * @param      {Object}  obj     The object
 * @param      {string}  field   The path to a field. Can include dots (.)
 * @param      {*}       val     The value to set the field
 * @return     {Object}  The modified object
 */
var setFieldValue = function(obj, field, val) {
    // using mpath.set() for this would be nice
    // but it does not create new objects as it traverses the path
    var parts = field.split('.');
    var partsLen = parts.length;
    var partRef = obj || {};
    var i, part;

    for (i = 0; i < partsLen; i++) {
        part = parts[i];

        if (i === partsLen - 1) {
            partRef[part] = val;
        } else {
            partRef[part] = partRef[part] || {};
            partRef = partRef[part];
        }
    }

    return obj;
};

/**
 * Pick a subset of fields from an object
 *
 * @param      {Object}   obj      The object
 * @param      {string[]} fields   The fields to pick. Can include dots (.)
 * @param      {Object}   [options]  The options
 * @param      {boolean}  [options.excludeUndefinedValues=false]  Whether undefined values should be included in returned object.
 * @return     {Object}   An object containing only those fields that have been picked
 */
var pick = function(obj, fields, options) {
    var result = {};
    var val;
    var options = options || {};
    _.defaults(options, {
        excludeUndefinedValues: false
    });

    fields.forEach(function(field) {
        val = mpath.get(field, obj);

        if (!options.excludeUndefinedValues || val !== undefined) {
            setFieldValue(result, field, val);
        }
    });

    return result;
};

/**
 * Determines if embedded document.
 *
 * @param      {Model}    doc     The Mongoose document
 * @return     {boolean}  True if embedded document, False otherwise.
 */
var isEmbeddedDocument = function (doc) {
    return doc.constructor.name === 'EmbeddedDocument' || doc.constructor.name === 'SingleNested';
};

module.exports = {
    setFieldValue: setFieldValue,
    pick: pick,
    isEmbeddedDocument: isEmbeddedDocument
};
