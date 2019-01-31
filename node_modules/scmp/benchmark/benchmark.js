var scmp = require('../');

// use safe-buffer in case Buffer.from in newer versions of node aren't
// available
var Buffer = require('safe-buffer').Buffer;

suite('scmp', function() {
  var HASH1 = Buffer.from('e727d1464ae12436e899a726da5b2f11d8381b26', 'hex');
  var HASH2 = Buffer.from('f727d1464ae12436e899a726da5b2f11d8381b26', 'hex');

  bench('short-circuit compares', function() {
    HASH1 === HASH2;
  });

  bench('scmp compares', function() {
    scmp(HASH1, HASH2);
  });

});
