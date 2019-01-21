'use strict';
var crypto = require('crypto');

/**
 * Derives 512 bit key from a string secret
 *
 * @param      {string}  secret  The secret
 * @param      {string}  type    The type of key to generate. Can be any string.
 * @return     {Buffer}  512 bit key
 */
var deriveKey = function (secret, type) {
    var hmac = crypto.createHmac('sha512', secret);
    hmac.update(type);
    return new Buffer(hmac.digest());
};

/**
 * Utility function: Zeros a buffer for security
 *
 * @param      {Buffer}  buf     The buffer
 */
var clearBuffer = function (buf) {
    for (var i = 0; i < buf.length; i++) {
        buf[i] = 0;
    }
};

/**
 * Drops 256 bits from a 512 bit buffer
 *
 * @param      {Buffer}  buf     A 512 bit buffer
 * @return     {Buffer}  A 256 bit buffer
 */
var drop256 = function (buf) {
    var buf256 = new Buffer(32);
    buf.copy(buf256, 0, 0, 32);

    clearBuffer(buf);
    return buf256;
};

module.exports = {
    deriveKey: deriveKey,
    clearBuffer: clearBuffer,
    drop256: drop256
};
