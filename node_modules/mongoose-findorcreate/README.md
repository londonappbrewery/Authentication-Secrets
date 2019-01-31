Mongoose findOrCreate Plugin [![Build Status](https://secure.travis-ci.org/drudge/mongoose-findorcreate.png?branch=master)](https://travis-ci.org/drudge/mongoose-findorcreate)
============================

Simple plugin for [Mongoose](https://github.com/LearnBoost/mongoose) which adds
a findOrCreate method to models. This is useful for libraries like
[Passport](http://passportjs.org) which require it.

## Installation

`npm install mongoose-findorcreate`

## Usage

```javascript
var findOrCreate = require('mongoose-findorcreate')
var ClickSchema = new Schema({ ... });
ClickSchema.plugin(findOrCreate);
var Click = mongoose.model('Click', ClickSchema);
```

The Click model now has a findOrCreate static method

```javascript
Click.findOrCreate({ip: '127.0.0.1'}, function(err, click, created) {
  // created will be true here
  console.log('A new click from "%s" was inserted', click.ip);
  Click.findOrCreate({}, function(err, click, created) {
    // created will be false here
    console.log('Did not create a new click for "%s"', click.ip);
  })
});
```

You can also include properties that aren't used in the
find call, but will be added to the object if it is created.

```javascript
Click.create({ip: '127.0.0.1'}, {browser: 'Mozilla'}, function(err, val) {
  Click.findOrCreate({ip: '127.0.0.1'}, {browser: 'Chrome'}, function(err, click) {
    console.log('A click from "%s" using "%s" was found', click.ip, click.browser);
    // prints A click from "127.0.0.1" using "Mozilla" was found
  })
});
```

### Promise Support

Choose your Promise library by setting
[`Mongoose.Promise`](http://mongoosejs.com/docs/promises.html).

The returned `Promise` shall resolve to an object with keys `doc` and
`created` on success. It shall be rejected with `err` on failure.

```javascript
// Use environment-provided Promise (necessary to silence a Mongoose warning).
mongoose.Promise = Promise;
// To a findOrCreate().
Click.findOrCreate({ip: '127.0.0.2'}).then(function (result) {
  click = result.doc;
  console.log('A click from', click.ip, ' using ', click.browser, ' was ', click.created ? 'created' : 'found');
})
```

## License

(The MIT License)

Copyright (c) 2012-2017 Nicholas Penree &lt;nick@penree.com&gt;

Based on [supergoose](https://github.com/jamplify/supergoose): Copyright (c) 2012 Jamplify

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
