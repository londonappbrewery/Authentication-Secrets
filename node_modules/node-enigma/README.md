node-enigma  [![Build Status](https://travis-ci.org/dyeboah/node-enigma.svg?branch=master)](https://travis-ci.org/dyeboah/node-enigma)  [![Coverage Status](https://coveralls.io/repos/github/dyeboah/node-enigma/badge.svg?branch=master)](https://coveralls.io/github/dyeboah/node-enigma?branch=master)
===========

Node.js module to cipher and decipher messages. 
This module is intended to imitate the operation of the Enigma M3/M4 developed during the WWII.
For more information on Enigma, visit [Enigma Cipher Machine](http://www.cryptomuseum.com/crypto/enigma/index.htm).

Contact me [@dyeboah](mailto:dyeboah@oswego.edu) with any questions, feedback or bugs.

Install
-------

  ```
  $ npm install node-enigma
  ```
  
Usage
-----

  ```javascript
  var Enigma = require('node-enigma');
  
  /**
  * M4 CONFIGURATION
  * WHEEL POSITIONS [4TH, 3RD, 2ND, 1ST, REFLECTOR]
  *
  * M3 CONFIGURATION
  * WHEEL POSITIONS [ 3RD, 2ND, 1ST, REFLECTOR]
  *
  * WHEELS 
  *   ROTORS['i','ii','iii','iv','v','vi','vii,'viii']
  *   REFLECTORS['ukw-b','ukw-c','b-thin','c-thin']
  *   GREEK['beta', 'gamma']
  */
  
  const m4 = new Enigma('beta','v','iv','iii','ukw-b');
  m4.setCode(['C', 'D', 'E']);
  m4.setPlugboard({
    'W': 'L',
    "D": "N"
   });
  m4.decode("OGRFHRJYV"); // XXXKMVOXH
  
  const m3 = new Enigma('v','iv','iii','ukw-b');
  m3.setCode(['A', 'B', 'C']);
  m3.setPlugboard({
    'Q': 'V',
    "S": "M"
   });
  m3.decode("OGRFHRJYV"); // INAPICKLE
  
  const enigma = new Enigma('i','ii','iii','ukw-b');
  enigma.encode("BABYDRIVER");  //ADLVITPHWX
  
  
  ```
  
  
  >Refer to test directory for more basic usage
  
  >⬆🔠
  
  
Contribute
----------

Clone this repo to add custom wheels. Make a script inside the folder to test outputs with `require('./lib/node-enigma')`. Any fixes, cleanup or new features are always appreciated.
