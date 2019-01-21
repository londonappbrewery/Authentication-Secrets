'use strict';

/**
 *  node-enigma.js
 */


var wheels = require("./wheels");
var clone = require("clone");

/**
 *  default values 
 */
const DEFAULT_CONFIG = {
 code: [0, 0, 0],

 plugboard: {
  'A': 'A',
  'B': 'B',
  'C': 'C',
  'D': 'D',
  'E': 'E',
  'F': 'F',
  'G': 'G',
  'H': 'H',
  'I': 'I',
  'J': 'J',
  'K': 'K',
  'L': 'L',
  'M': 'M',
  'N': 'N',
  'O': 'O',
  'P': 'P',
  'Q': 'Q',
  'R': 'R',
  'S': 'S',
  'T': 'T',
  'U': 'U',
  'V': 'V',
  'W': 'W',
  'X': 'X',
  'Y': 'Y',
  'Z': 'Z'
 }
};

/**
 *  an array of signals 
 */
const SIGNALS = [(input, code) => {
  var signal = (getIndex(input) + code[2]) % 26;
  return (signal < 0) ? signal + 26 : signal;
 },
 (input, code) => {
  var signal = (getIndex(input) + (code[1] - code[2])) % 26;
  return (signal < 0) ? signal + 26 : signal;
 },
 (input, code) => {
  var signal = (getIndex(input) + (code[0] - code[1])) % 26;
  return (signal < 0) ? signal + 26 : signal;
 },
 (input, code) => {
  var signal = (getIndex(input) - code[0]) % 26;
  return (signal < 0) ? signal + 26 : signal;
 },
 (input, code) => {
  var signal = getIndex(input);
  return signal;
 },
 (input, code) => {
  var signal = getIndex(input);
  return wheels['etw'][signal];
 },
 (input, code) => {
  var signal = (getIndex(input) + code[0]) % 26;
  return wheels['etw'][(signal < 0) ? signal + 26 : signal];
 },
 (input, code) => {
  var signal = (getIndex(input) + (code[1] - code[0])) % 26;
  return wheels['etw'][(signal < 0) ? signal + 26 : signal];
 },
 (input, code) => {
  var signal = (getIndex(input) + (code[2] - code[1])) % 26;
  return wheels['etw'][(signal < 0) ? signal + 26 : signal];
 },
 (input, code) => {
  var signal = (getIndex(input) - (code[2])) % 26;
  return wheels['etw'][(signal < 0) ? signal + 26 : signal];
 }
];

/**
 *  constructor
 *
 * @param {string} rotor_1
 * @param {string} rotor_2
 * @param {string} rotor_3
 * @param {string} rotor_4
 * @param {string} reflector
 *  
 */				
function Enigma(rotor_4, rotor_3, rotor_2, rotor_1, reflector) {
 this.rotors = [wheels[rotor_1], wheels[rotor_2], wheels[rotor_3]];
 this.code = null;
 this.plugboard = null;
 this.flag = false;
 this.defaultConfig = clone(DEFAULT_CONFIG);
 this.signals = clone(SIGNALS);

 if (typeof reflector !== 'undefined') {

  // M4 Configuration
  this.rotors.push(wheels[rotor_4]);
  this.rotors.push(wheels[reflector]);
  this.midJourney = 3;
  this.journey = 8;
 } else {

  // M3 Configuration
  this.rotors.push(wheels[rotor_4])
  this.rotors.push(this.rotors.shift());
  this.signals.splice(4, 2);
  this.midJourney = 2;
  this.journey = 6;
 }



}

/**
 * sets ring settings
 *
 * @param  {Array} code
 * ex. ['A','B','Z']
 */
Enigma.prototype.setCode = function(code) {
 this.code = this.defaultConfig['code'];
 var etw = wheels['etw'];
 for (var i in code) {
  this.code[i] = etw.indexOf(code[i]);
 }
}


/**
 * sets plug pairs
 *
 * @param  {Object} plugboard 
 * ex. {'A':'B','Z':'V'}
 */
Enigma.prototype.setPlugboard = function(plugboard) {
 this.plugboard = this.defaultConfig['plugboard'];
 for (var i in plugboard) {
  this.plugboard[i] = plugboard[i];
  this.plugboard[plugboard[i]] = i;
 }
}


/**
 * increments ring/code settings 
 */
function increment() {
 var etw = wheels['etw'];
 var code = this.code || this.defaultConfig['code'];
 var rotors = this.rotors;


 if (!rotors[1].turnover.split('').includes(etw[code[1]])) this.flag = false;

 if (rotors[1].turnover.split('').includes(etw[code[1]]) && !this.flag) {
  code[2] = (code[2] + 1) % 26;
  code[1] = (code[1] + 1) % 26;
  code[0] = (code[0] + 1) % 26;
  this.flag = true;
  this.code = code;
  return;
 }

 if (rotors[0].turnover.split('').includes(etw[code[2]])) {
  code[2] = (code[2] + 1) % 26;
  code[1] = (code[1] + 1) % 26;
  this.code = code;
  return;
 }



 code[2] = (code[2] + 1) % 26;
 this.code = code;
}

/**
 * returns the index of a letter
 *
 * @param {string} input - letter
 * @return {number} 
 */
var getIndex = function(input) {
 return wheels['etw'].indexOf(input);
}


/**
 * ciphers plaintext
 *
 * @param {string} input 
 * @returns {string} 
 */
Enigma.prototype.encode = function(input) {
 var plugboard = this.plugboard || this.defaultConfig['plugboard'];
 var rotors = this.rotors;
 var signals = this.signals;
 var etw = wheels['etw'];
 var code = null;
 var ciphertext = "";

 [...input.toUpperCase()].forEach((char) => {
  increment.call(this);
  code = this.code;
  char = plugboard[char];

  var forward = 0,
   phase = forward,
   reverse = this.midJourney;
  while (forward <= this.journey) {	
   var isReflected = forward < rotors.length; // checks if journey has reach relector
   char = isReflected ? rotors[forward].wire[signals[phase](char, code)] :
    etw[rotors[reverse].wire.indexOf(signals[phase](char, code))];
   if (!isReflected) reverse--;
   forward++;
   phase++;
  }

  char = plugboard[signals[phase](char, code)];

  ciphertext += char;
 });

 return ciphertext;

}

/**
 * deciphers ciphertext
 *
 * @param {string} input 
 * @returns {string} 
 */
Enigma.prototype.decode = function(input) {
 return this.encode(input);
}


module.exports = Enigma;
