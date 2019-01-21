var dotty = require('dotty');
var _ = require('underscore');

var objectUtil = require('../util/object-util.js');

var isEmbeddedDocument = objectUtil.isEmbeddedDocument;

/**
 * Synchronously decrypt any embedded documents inside of this document
 * @param  {mongoose document}  document   The mongoose document
 */
module.exports = function decryptEmbeddedDocs (doc) {
    _.keys(doc.schema.paths).forEach(function (path) {
        if (path === '_id' || path === '__v') {
            return;
        }

        var nestedDoc = dotty.get(doc, path);

        if (nestedDoc && nestedDoc[0] && isEmbeddedDocument(nestedDoc[0])) {
            nestedDoc.forEach(function (subDoc) {
                if (_.isFunction(subDoc.decryptSync)) {
                    subDoc.decryptSync();
                }
            });
        }
    });
};
