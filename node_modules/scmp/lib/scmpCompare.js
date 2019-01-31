module.exports = function scmpCompare (a, b) {
  var len = a.length;
  var result = 0;
  for (var i = 0; i < len; ++i) {
    result |= a[i] ^ b[i];
  }
  return result === 0;
}
