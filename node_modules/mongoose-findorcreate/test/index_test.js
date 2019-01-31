
/**
 * @list dependencies
 **/

var mocha = require('mocha');
var should = require('should');
var mongoose = require('mongoose');
var Schema = mongoose.Schema;
var findOrCreate = require('../');

mongoose.connect('mongodb://localhost/findOrCreate');
mongoose.connection.on('error', function (err) {
  console.error('MongoDB error: ' + err.message);
  console.error('Make sure a mongoDB server is running and accessible by this application')
});

var ClickSchema = new Schema({
  ip : {type: String, required: true},
  hostname : {type: String, required: false}
})

ClickSchema.plugin(findOrCreate);

var Click = mongoose.model('Click', ClickSchema);

after(function(done) {
  mongoose.connection.db.dropDatabase(function() {
    mongoose.connection.close();
    done();
  });
})

describe('findOrCreate', function() {
  it("should create the object if it doesn't exist", function(done) {
    Click.findOrCreate({ip: '127.0.0.1'}, function(err, click) {
      click.ip.should.eql('127.0.0.1')
      Click.count({}, function(err, num) {
        num.should.equal(1)
        done();
      })
    })
  })

  it("returns the object if it already exists", function(done) {
    Click.create({ip: '127.0.0.2'}, function(){
      Click.findOrCreate({ip: '127.0.0.2'}, function(err, click) {
        click.ip.should.eql('127.0.0.2')
        Click.count({ip: '127.0.0.2'}, function(err, num) {
          num.should.equal(1)
          done();
        })
      })
    })
  })

  it("should pass created as true if the object didn't exist", function(done) {
    Click.findOrCreate({ip: '127.1.1.1'}, function(err, click, created) {
      created.should.eql(true);
      done();
    })
  })

  it("should pass created as false if the object already exists", function(done) {
    Click.findOrCreate({ip: '127.1.1.1'}, function(err, click, created) {
      created.should.eql(false);
      done();
    })
  })

  it("should not add properties with a $ when creating the object", function(done) {
    Click.findOrCreate({
      ip: '127.2.2.2',
      subnet: { $exists: true }
    }, function(err, click, created) {
      click.should.be.an.Object;
      click.ip.should.eql('127.2.2.2');
      should.not.exist(click.subnet);
      created.should.eql(true);
      done();
    })
  })

  it("should not add properties with a $ when creating an object different from the find call", function(done) {
    Click.findOrCreate({
      ip: '127.3.3.3',
      subnet: { $exists: true }
    }, {
      ip: '127.3.3.3',
      subnet: { $exists: true },
      hostname: 'noplacelikehome'
    }, function(err, click, created) {
      click.should.be.an.Object;
      click.ip.should.eql('127.3.3.3');
      should.not.exist(click.subnet);
      click.hostname.should.eql('noplacelikehome');
      created.should.eql(true);
      done();
    })
  })


  it("should support upsert", function(done) {
    // Create something to upsert.
    new Click({
      ip: '128.0.0.0',
    }).save(function (err, click) {
      click.should.be.an.Object;
      click.ip.should.eql('128.0.0.0');
      should.equal(click.hostname, null);
      // Upsert to add a hostname.
      Click.findOrCreate({
        ip: '128.0.0.0',
      }, {
        hostname: 'example.org',
      }, {
        upsert: true,
      }, function (err, click, created) {
        click.should.be.an.Object;
        click.ip.should.eql('128.0.0.0');
        click.hostname.should.eql('example.org');
        created.should.eql(false);
        // Verify that it actually was updated in the database.
        Click.findOne({
          ip: '128.0.0.0',
        }, function (err, click) {
          click.should.be.an.Object;
          click.ip.should.eql('128.0.0.0');
          click.hostname.should.eql('example.org');
          done();
        });
      });
    });
  })

  it("should return updated instance after upserting away from the condition", function(done) {
    // Create something to upsert.
    new Click({
      ip: '128.1.1.1',
    }).save(function(err, click) {
      var _id = click._id;
      click.should.be.an.Object;
      click.ip.should.eql('128.1.1.1');
      // Upsert in such a way that it no longer matches conditions.
      Click.findOrCreate({
        ip: '128.1.1.1',
      }, {
        ip: '128.1.1.2',
      }, {
        upsert: true,
      }, function(err, click, created) {
        // Should have returned upserted object even though it no
        // longer matches the conditions.
        click.should.be.an.Object
        click.ip.should.eql('128.1.1.2');
        created.should.eql(false);
        // Verify that it actually was updated in the database.
        Click.findById(_id, function (err, click) {
          click.should.be.an.Object;
          click.ip.should.eql('128.1.1.2');
          done();
        })
      })
    })
  })

  it("should return a Promise when passed conditions", function() {
    var ret = Click.findOrCreate({
      ip: '127.4.4.4',
    });
    ret.should.be.a.Promise;
    return ret.then(function(click) {
      click.should.be.an.Object;
      click.doc.should.be.an.Object;
      click.doc.ip.should.eql('127.4.4.4');
      click.created.should.eql(true);
    })
  })

  it("should return a Promise when passed conditions, doc", function() {
    var ret = Click.findOrCreate({
      ip: '127.4.4.4',
    }, {
      ip: '127.5.5.5',
    });
    ret.should.be.a.Promise;
    return ret.then(function(result) {
      result.should.be.an.Object;
      result.doc.should.be.an.Object;
      result.doc.ip.should.eql('127.4.4.4');
      result.created.should.eql(false);
    })
  })

  it("should return a Promise when passed conditions, doc, options", function() {
    var ret = Click.findOrCreate({
      ip: '127.4.4.4',
    }, {
      ip: '127.5.5.5',
    }, {
      upsert: true,
    });
    ret.should.be.a.Promise;
    return ret.then(function (result) {
      result.should.be.an.Object;
      result.doc.should.be.an.Object;
      result.doc.ip.should.eql('127.5.5.5');
      result.created.should.eql(false);
    })
  })
})
