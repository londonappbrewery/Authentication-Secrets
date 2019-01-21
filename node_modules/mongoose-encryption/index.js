'use strict';

module.exports = require('./lib/plugins/mongoose-encryption');
module.exports.encryptedChildren = require('./lib/plugins/encrypted-children.js');
module.exports.migrations = require('./lib/plugins/migrations.js');
