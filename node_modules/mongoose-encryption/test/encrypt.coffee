mongoose = require 'mongoose'
bufferEqual = require 'buffer-equal-constant-time'
sinon = require 'sinon'
chai = require 'chai'
assert = chai.assert
mongoose.connect 'mongodb://localhost/mongoose-encryption-test'

encryptionKey = 'CwBDwGUwoM5YzBmzwWPSI+KjBKvWHaablbrEiDYh43Q='
signingKey = 'dLBm74RU4NW3e2i3QSifZDNXIXBd54yr7mZp0LKugVUa1X1UP9qoxoa3xfA7Ea4kdVL+JsPg9boGfREbPCb+kw=='
secret = 'correct horse battery staple CtYC/wFXnLQ1Dq8lYZSbnDuz8fTYMALPfgCqdgtpcrc'

encrypt = require '../index.js'

BasicEncryptedModel = null

BasicEncryptedModelSchema = mongoose.Schema
  text: type: String
  bool: type: Boolean
  num: type: Number
  date: type: Date
  id2: type: mongoose.Schema.Types.ObjectId
  arr: [ type: String ]
  mix: type: mongoose.Schema.Types.Mixed
  buf: type: Buffer
  idx: type: String, index: true

BasicEncryptedModelSchema.plugin encrypt, secret: secret

BasicEncryptedModel = mongoose.model 'Simple', BasicEncryptedModelSchema

describe 'encrypt plugin', ->
  it 'should add field _ct of type Buffer to the schema', ->
    encryptedSchema = mongoose.Schema({}).plugin(encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'test')
    assert.property encryptedSchema.paths, '_ct'
    assert.propertyVal encryptedSchema.paths._ct, 'instance', 'Buffer'

  it 'should add field _ac of type Buffer to the schema', ->
    encryptedSchema = mongoose.Schema({}).plugin(encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'test')
    assert.property encryptedSchema.paths, '_ac'
    assert.propertyVal encryptedSchema.paths._ac, 'instance', 'Buffer'

  it 'should expose an encrypt method on documents', ->
    EncryptFnTestModel = mongoose.model 'EncryptFnTest', mongoose.Schema({}).plugin(encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'test')
    assert.isFunction (new EncryptFnTestModel).encrypt

  it 'should expose a decrypt method on documents', ->
    DecryptFnTestModel = mongoose.model 'DecryptFnTest', mongoose.Schema({}).plugin(encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'test')
    assert.isFunction (new DecryptFnTestModel).decrypt

  it 'should expose a decryptSync method on documents', ->
    DecryptSyncFnTestModel = mongoose.model 'DecryptSyncFnTest', mongoose.Schema({}).plugin(encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'test')
    assert.isFunction (new DecryptSyncFnTestModel).decryptSync

  it 'should expose a sign method on documents', ->
    SignFnTestModel = mongoose.model 'SignFnTest', mongoose.Schema({}).plugin(encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'test')
    assert.isFunction (new SignFnTestModel).sign

  it 'should expose a authenticateSync method on documents', ->
    AuthenticateSyncFnTestModel = mongoose.model 'AuthenticateSyncFnTest', mongoose.Schema({}).plugin(encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'test')
    assert.isFunction (new AuthenticateSyncFnTestModel).authenticateSync

  it 'should throw an error if installed twice on the same schema', ->
    EncryptedSchema = mongoose.Schema
      text: type: String
    EncryptedSchema.plugin encrypt, secret: secret
    assert.throw -> EncryptedSchema.plugin encrypt, secret: secret

describe 'new EncryptedModel', ->
  it 'should remain unaltered', (done) ->
    simpleTestDoc1 = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'

    assert.propertyVal simpleTestDoc1, 'text', 'Unencrypted text'
    assert.propertyVal simpleTestDoc1, 'bool', true
    assert.propertyVal simpleTestDoc1, 'num', 42
    assert.property simpleTestDoc1, 'date'
    assert.equal simpleTestDoc1.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
    assert.equal simpleTestDoc1.id2.toString(), '5303e65d34e1e80d7a7ce212'
    assert.lengthOf simpleTestDoc1.arr, 2
    assert.equal simpleTestDoc1.arr[0], 'alpha'
    assert.equal simpleTestDoc1.arr[1], 'bravo'
    assert.property simpleTestDoc1, 'mix'
    assert.deepEqual simpleTestDoc1.mix, { str: 'A string', bool: false }
    assert.property simpleTestDoc1, 'buf'
    assert.equal simpleTestDoc1.buf.toString(), 'abcdefg'
    assert.property simpleTestDoc1, '_id'
    assert.notProperty simpleTestDoc1, '_ct'
    done()

describe 'document.save()', ->
  before ->
    @sandbox = sinon.sandbox.create()
    @sandbox.spy BasicEncryptedModel.prototype, 'sign'
    @sandbox.spy BasicEncryptedModel.prototype, 'encrypt'
    @sandbox.spy BasicEncryptedModel.prototype, 'decryptSync'

  after ->
    @sandbox.restore()

  beforeEach (done) ->
    BasicEncryptedModel.prototype.sign.reset()
    BasicEncryptedModel.prototype.encrypt.reset()
    BasicEncryptedModel.prototype.decryptSync.reset()

    @simpleTestDoc2 = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'

    @simpleTestDoc2.save (err) =>
      assert.equal err, null
      done()

  afterEach (done) ->
    @simpleTestDoc2.remove (err) ->
      assert.equal err, null
      done()

  it 'saves encrypted fields', (done) ->
    BasicEncryptedModel.find
      _id: @simpleTestDoc2._id
      _ct: $exists: true
      text: $exists: false
      bool: $exists: false
      num: $exists: false
      date: $exists: false
      id2: $exists: false
      arr: $exists: false
      mix: $exists: false
      buf: $exists: false
    , (err, docs) ->
      assert.equal err, null
      assert.lengthOf docs, 1
      done()

  it 'returns decrypted data after save', (done) ->
    @simpleTestDoc2.save (err, doc) ->
      return done(err) if err

      try
        assert.equal doc._ct, undefined
        assert.equal doc._ac, undefined
        assert.equal doc.text, 'Unencrypted text'
        assert.equal doc.bool, true
        assert.equal doc.num, 42
        assert.deepEqual doc.date, new Date('2014-05-19T16:39:07.536Z')
        assert.equal doc.id2, '5303e65d34e1e80d7a7ce212'
        assert.equal doc.arr.toString(), ['alpha', 'bravo'].toString()
        assert.deepEqual doc.mix, { str: 'A string', bool: false }
        assert.deepEqual doc.buf, new Buffer 'abcdefg'
        done()
      catch err
        done err

   it 'should have called encryptSync then authenticateSync then decryptSynd', ->
    assert.equal @simpleTestDoc2.sign.callCount, 1
    assert.equal @simpleTestDoc2.encrypt.callCount, 1
    assert.equal @simpleTestDoc2.decryptSync.callCount, 1
    assert @simpleTestDoc2.encrypt.calledBefore @simpleTestDoc2.decryptSync
    assert @simpleTestDoc2.encrypt.calledBefore @simpleTestDoc2.sign, 'encrypted before signed'
    assert @simpleTestDoc2.sign.calledBefore @simpleTestDoc2.decryptSync, 'signed before decrypted'

describe 'document.save() on encrypted document which contains nesting', ->
  before ->
    @schemaWithNest = mongoose.Schema
      nest:
        birdColor: type: String
        areBirdsPretty: type: Boolean

    @schemaWithNest.plugin encrypt, secret: secret

    @ModelWithNest = mongoose.model 'SimpleNest', @schemaWithNest

  beforeEach (done) ->

    @nestTestDoc = new @ModelWithNest
      nest:
        birdColor: 'blue'
        areBirdsPretty: true

    @nestTestDoc.save (err) ->
      assert.equal err, null
      done()

  afterEach (done) ->
    @nestTestDoc.remove (err) ->
      assert.equal err, null
      done()

  it 'encrypts nested fields', (done) ->
    @ModelWithNest.find(
      _id: @nestTestDoc._id
      _ct: $exists: true
      nest: $exists: false
    ).lean().exec (err, docs) ->
      assert.equal err, null
      assert.lengthOf docs, 1
      done()

  it 'saves encrypted fields', (done) ->
    @ModelWithNest.find
      _id: @nestTestDoc._id
      _ct: $exists: true
    , (err, docs) ->
      assert.equal err, null
      assert.lengthOf docs, 1
      assert.isObject docs[0].nest
      assert.propertyVal docs[0].nest, 'birdColor', 'blue'
      assert.propertyVal docs[0].nest, 'areBirdsPretty', true
      done()

describe 'document.save() on encrypted nested document', ->
  before ->
    @schema = mongoose.Schema
      birdColor: type: String
      areBirdsPretty: type: Boolean

    @schema.plugin encrypt, secret: secret, collectionId: 'schema', encryptedFields: ['birdColor']

    @schemaWithNest = mongoose.Schema
      nest: @schema

    @ModelWithNest = mongoose.model 'SimpleNestedBird', @schemaWithNest

  beforeEach (done) ->

    @nestTestDoc = new @ModelWithNest
      nest:
        birdColor: 'blue'
        areBirdsPretty: true

    @nestTestDoc.save (err, doc) ->
      assert.equal err, null
      done()

  afterEach (done) ->
    @nestTestDoc.remove (err) ->
      assert.equal err, null
      done()

  it 'encrypts nested fields', (done) ->
    @ModelWithNest.find(
      _id: @nestTestDoc._id
      'nest._ct': $exists: true
      'nest.birdColor': $exists: false
    ).lean().exec (err, docs) ->
      assert.equal err, null
      assert.lengthOf docs, 1
      done()

  it 'saves encrypted fields', (done) ->
    @ModelWithNest.find
      _id: @nestTestDoc._id
      'nest._ct': $exists: true
    , (err, docs) ->
      assert.equal err, null
      assert.lengthOf docs, 1
      assert.isObject docs[0].nest
      assert.propertyVal docs[0].nest, 'birdColor', 'blue'
      assert.propertyVal docs[0].nest, 'areBirdsPretty', true
      done()

describe 'document.save() when only certain fields are encrypted', ->
  before ->
    PartiallyEncryptedModelSchema = mongoose.Schema
      encryptedText: type: String
      unencryptedText: type: String

    PartiallyEncryptedModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'PartiallyEncrypted', encryptedFields: ['encryptedText']

    @PartiallyEncryptedModel = mongoose.model 'PartiallyEncrypted', PartiallyEncryptedModelSchema

  beforeEach (done) ->
    @partiallyEncryptedDoc = new @PartiallyEncryptedModel
      encryptedText: 'Encrypted Text'
      unencryptedText: 'Unencrypted Text'

    @partiallyEncryptedDoc.save (err) ->
      assert.equal err, null
      done()

  afterEach (done) ->
    @partiallyEncryptedDoc.remove (err) ->
      assert.equal err, null
      done()

  it 'should have decrypted fields', ->
    assert.equal @partiallyEncryptedDoc.encryptedText, 'Encrypted Text'
    assert.propertyVal @partiallyEncryptedDoc, 'unencryptedText', 'Unencrypted Text'

  it 'should have encrypted fields undefined when encrypt is called', (done) ->
    @partiallyEncryptedDoc.encrypt =>
      assert.equal @partiallyEncryptedDoc.encryptedText, undefined
      assert.propertyVal @partiallyEncryptedDoc, 'unencryptedText', 'Unencrypted Text'
      done()

  it 'should have a field _ct containing a mongoose Buffer object which appears encrypted when encrypted', (done) ->
    @partiallyEncryptedDoc.encrypt =>
      assert.isObject @partiallyEncryptedDoc._ct
      assert.property @partiallyEncryptedDoc.toObject()._ct, 'buffer'
      assert.instanceOf @partiallyEncryptedDoc.toObject()._ct.buffer, Buffer
      assert.isString @partiallyEncryptedDoc.toObject()._ct.toString(), 'ciphertext can be converted to a string'
      assert.throw -> JSON.parse @partiallyEncryptedDoc.toObject()._ct.toString(), 'ciphertext is not parsable json'
      done()

  it 'should not overwrite _ct or _ac when saved after a find that didnt retrieve _ct or _ac', (done) ->
    @PartiallyEncryptedModel.findById(@partiallyEncryptedDoc).select('unencryptedText').exec (err, doc) =>
      assert.equal err, null
      assert.equal doc._ct, undefined
      assert.equal doc._ac, undefined
      assert.propertyVal doc, 'unencryptedText', 'Unencrypted Text', 'selected unencrypted fields should be found'
      doc.save (err) =>
        assert.equal err, null
        @PartiallyEncryptedModel.findById(@partiallyEncryptedDoc).select('unencryptedText _ct _ac').exec (err, finalDoc) ->
          assert.equal err, null
          assert.equal finalDoc._ct, undefined
          assert.propertyVal finalDoc, 'unencryptedText', 'Unencrypted Text', 'selected unencrypted fields should still be found after the select -> save'
          assert.propertyVal finalDoc, 'encryptedText', 'Encrypted Text', 'encrypted fields werent overwritten during the select -> save'
          done()

describe 'EncryptedModel.create()', ->

  beforeEach ->
    @docContents =
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'

  afterEach (done) ->
    BasicEncryptedModel.remove (err) ->
      assert.equal err, null
      done()

  it 'when doc created, it should pass an unencrypted version to the callback', (done) ->
    BasicEncryptedModel.create @docContents, (err, doc) ->
      assert.equal err, null
      assert.propertyVal doc, 'text', 'Unencrypted text'
      assert.propertyVal doc, 'bool', true
      assert.propertyVal doc, 'num', 42
      assert.property doc, 'date'
      assert.equal doc.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
      assert.equal doc.id2.toString(), '5303e65d34e1e80d7a7ce212'
      assert.lengthOf doc.arr, 2
      assert.equal doc.arr[0], 'alpha'
      assert.equal doc.arr[1], 'bravo'
      assert.property doc, 'mix'
      assert.deepEqual doc.mix, { str: 'A string', bool: false }
      assert.property doc, 'buf'
      assert.equal doc.buf.toString(), 'abcdefg'
      assert.property doc, '_id'
      assert.notProperty doc, '_ct'
      done()

  it 'after doc created, should be encrypted in db', (done) ->
    BasicEncryptedModel.create @docContents, (err, doc) ->
      assert.equal err, null
      assert.ok doc._id
      BasicEncryptedModel.find
        _id: doc._id
        _ct: $exists: true
        text: $exists: false
        bool: $exists: false
        num: $exists: false
        date: $exists: false
        id2: $exists: false
        arr: $exists: false
        mix: $exists: false
        buf: $exists: false
      , (err, docs) ->
        assert.lengthOf docs, 1
        done err


describe 'EncryptedModel.find()', ->
  simpleTestDoc3 = null

  before (done) ->
    @sandbox = sinon.sandbox.create()
    @sandbox.spy BasicEncryptedModel.prototype, 'authenticateSync'
    @sandbox.spy BasicEncryptedModel.prototype, 'decryptSync'
    simpleTestDoc3 = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
    simpleTestDoc3.save (err) ->
      assert.equal err, null
      done()

  beforeEach ->
    BasicEncryptedModel.prototype.authenticateSync.reset()
    BasicEncryptedModel.prototype.decryptSync.reset()

  after (done) ->
    @sandbox.restore()
    simpleTestDoc3.remove (err) ->
      assert.equal err, null
      done()

  it 'when doc found, should pass an unencrypted version to the callback', (done) ->
    BasicEncryptedModel.findById simpleTestDoc3._id, (err, doc) ->
      assert.equal err, null
      assert.propertyVal doc, 'text', 'Unencrypted text'
      assert.propertyVal doc, 'bool', true
      assert.propertyVal doc, 'num', 42
      assert.property doc, 'date'
      assert.equal doc.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
      assert.equal doc.id2.toString(), '5303e65d34e1e80d7a7ce212'
      assert.lengthOf doc.arr, 2
      assert.equal doc.arr[0], 'alpha'
      assert.equal doc.arr[1], 'bravo'
      assert.property doc, 'mix'
      assert.deepEqual doc.mix, { str: 'A string', bool: false }
      assert.property doc, 'buf'
      assert.equal doc.buf.toString(), 'abcdefg'
      assert.property doc, '_id'
      assert.notProperty doc, '_ct'
      done()

  it 'when doc not found by id, should pass null to the callback', (done) ->
    BasicEncryptedModel.findById '534ec48d60069bc13338b354', (err, doc) ->
      assert.equal err, null
      assert.equal doc, null
      done()

  it 'when doc not found by query, should pass [] to the callback', (done) ->
    BasicEncryptedModel.find text: 'banana', (err, doc) ->
      assert.equal err, null
      assert.isArray doc
      assert.lengthOf doc, 0
      done()

  it 'should have called authenticateSync then decryptSync', (done) ->
    BasicEncryptedModel.findById simpleTestDoc3._id, (err, doc) ->
      assert.equal err, null
      assert.ok doc
      assert.equal doc.authenticateSync.callCount, 1
      assert.equal doc.decryptSync.callCount, 1
      assert doc.authenticateSync.calledBefore doc.decryptSync, 'authenticated before decrypted'
      done()

  it 'if all authenticated fields selected, should not throw an error', (done) ->
    BasicEncryptedModel.findById(simpleTestDoc3._id).select('_ct _ac').exec (err, doc) ->
      assert.equal err, null
      assert.propertyVal doc, 'text', 'Unencrypted text'
      assert.propertyVal doc, 'bool', true
      assert.propertyVal doc, 'num', 42
      done()

  it 'if only some authenticated fields selected, should throw an error', (done) ->
    BasicEncryptedModel.findById(simpleTestDoc3._id).select('_ct').exec (err, doc) ->
      assert.ok err
      BasicEncryptedModel.findById(simpleTestDoc3._id).select('_ac').exec (err, doc) ->
        assert.ok err
        done()


describe 'EncryptedModel.find() lean option', ->
  simpleTestDoc4 = null
  before (done) ->
    simpleTestDoc4 = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
    simpleTestDoc4.save (err) ->
      assert.equal err, null
      done()

  after (done) ->
    simpleTestDoc4.remove (err) ->
      assert.equal err, null
      done()

  it 'should have encrypted fields undefined on saved document', (done) ->
    BasicEncryptedModel.findById(simpleTestDoc4._id).lean().exec (err, doc) ->
      assert.equal doc.text, undefined
      assert.equal doc.bool, undefined
      assert.equal doc.num, undefined
      assert.equal doc.date, undefined
      assert.equal doc.id2, undefined
      assert.equal doc.arr, undefined
      assert.equal doc.mix, undefined
      assert.equal doc.buf, undefined
      done()

  it 'should have a field _ct containing a mongoose Buffer object which appears encrypted', (done) ->
    BasicEncryptedModel.findById(simpleTestDoc4._id).lean().exec (err, doc) ->
      assert.isObject doc._ct
      assert.property doc._ct, 'buffer'
      assert.instanceOf doc._ct.buffer, Buffer
      assert.isString doc._ct.toString(), 'ciphertext can be converted to a string'
      assert.throw -> JSON.parse doc._ct.toString(), 'ciphertext is not parsable json'
      done()


describe 'document.encrypt()', ->
  simpleTestDoc5 = null
  beforeEach (done) ->
    simpleTestDoc5 = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    simpleTestDoc5.encrypt (err) ->
      assert.equal err, null
      done()

  it 'should have encrypted fields undefined', (done) ->
    assert.equal simpleTestDoc5.text, undefined
    assert.equal simpleTestDoc5.bool, undefined
    assert.equal simpleTestDoc5.num, undefined
    assert.equal simpleTestDoc5.date, undefined
    assert.equal simpleTestDoc5.id2, undefined
    assert.equal simpleTestDoc5.arr, undefined
    assert.equal simpleTestDoc5.mix, undefined
    assert.equal simpleTestDoc5.buf, undefined
    done()

  it 'should not encrypt indexed fields by default', (done) ->
    assert.propertyVal simpleTestDoc5, 'idx', 'Indexed'
    done()

  it 'should have a field _ct containing a mongoose Buffer object which appears encrypted', (done) ->
    assert.isObject simpleTestDoc5._ct
    assert.property simpleTestDoc5.toObject()._ct, 'buffer'
    assert.instanceOf simpleTestDoc5.toObject()._ct.buffer, Buffer
    assert.isString simpleTestDoc5.toObject()._ct.toString(), 'ciphertext can be converted to a string'
    assert.throw -> JSON.parse simpleTestDoc5.toObject()._ct.toString(), 'ciphertext is not parsable json'
    done()

  it 'should have non-ascii characters in ciphertext as a result of encryption even if all input is ascii', (done) ->
    allAsciiDoc = new BasicEncryptedModel
      text: 'Unencrypted text'

    allAsciiDoc.encrypt (err) ->
      assert.equal err, null
      assert.notMatch allAsciiDoc.toObject()._ct.toString(), /^[\x00-\x7F]*$/
      done()

  it 'should pass an error when called on a document which is already encrypted', (done) ->
    simpleTestDoc5.encrypt (err) ->
      assert.ok err
      done()



describe 'document.decrypt()', ->
  beforeEach (done) ->
    @encryptedSimpleTestDoc = new BasicEncryptedModel
      _id: '584b1e7de752fcf3be8cd086'
      idx: 'Indexed'
      _ct: new Buffer("610bbddbf35455e9a4fcf2428bb6cd68f39fdaece7e851cb213b1be81b10559d1af6d7c205752d2a6620100871d0e" +
                      "95d3609d4ee81795dcc7ef5130b80f117eb12f557a08d4837609f37d24af8d64f8b5072747e1a9e4585fc07d76720" +
                      "5e8289235019f818ad7ed9dbb90844d6a42189ab5a8cdc303e60256dbc5daa76386422de8cf1af40ea1c07b7720e5" +
                      "3787515a959537f4dffc663c69d29e614621bc7a345ab31f9b8931277d7577962e9558119b9d5d7db0a3b1c298afd" +
                      "eabe11581684b62ffaa58a9877d7ceeeb2ea158df3db7881bfedb40ed4d4de7a6465cf1e1148582714279bd0e0cbf" +
                      "f145e0bddc1ff3f5e2e6cc8b39f9640e433e4c4140e2095e6", 'hex');

    @simpleTestDoc6 = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    @simpleTestDoc6.encrypt (err) ->
      assert.equal err, null
      done()

  it 'should return an unencrypted version', (done) ->
    @encryptedSimpleTestDoc.decrypt (err) =>
      assert.equal err, null
      assert.propertyVal @encryptedSimpleTestDoc, 'text', 'Unencrypted text'
      assert.propertyVal @encryptedSimpleTestDoc, 'bool', true
      assert.propertyVal @encryptedSimpleTestDoc, 'num', 42
      assert.property @encryptedSimpleTestDoc, 'date'
      assert.equal @encryptedSimpleTestDoc.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
      assert.equal @encryptedSimpleTestDoc.id2.toString(), '5303e65d34e1e80d7a7ce212'
      assert.lengthOf @encryptedSimpleTestDoc.arr, 2
      assert.equal @encryptedSimpleTestDoc.arr[0], 'alpha'
      assert.equal @encryptedSimpleTestDoc.arr[1], 'bravo'
      assert.property @encryptedSimpleTestDoc, 'mix'
      assert.deepEqual @encryptedSimpleTestDoc.mix, { str: 'A string', bool: false }
      assert.property @encryptedSimpleTestDoc, 'buf'
      assert.equal @encryptedSimpleTestDoc.buf.toString(), 'abcdefg'
      assert.propertyVal @encryptedSimpleTestDoc, 'idx', 'Indexed'
      assert.property @encryptedSimpleTestDoc, '_id'
      assert.notProperty @encryptedSimpleTestDoc, '_ct'
      done()

  it 'should return an unencrypted version when run after #encrypt', (done) ->
    @simpleTestDoc6.decrypt (err) =>
      assert.equal err, null
      assert.propertyVal @simpleTestDoc6, 'text', 'Unencrypted text'
      assert.propertyVal @simpleTestDoc6, 'bool', true
      assert.propertyVal @simpleTestDoc6, 'num', 42
      assert.property @simpleTestDoc6, 'date'
      assert.equal @simpleTestDoc6.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
      assert.equal @simpleTestDoc6.id2.toString(), '5303e65d34e1e80d7a7ce212'
      assert.lengthOf @simpleTestDoc6.arr, 2
      assert.equal @simpleTestDoc6.arr[0], 'alpha'
      assert.equal @simpleTestDoc6.arr[1], 'bravo'
      assert.property @simpleTestDoc6, 'mix'
      assert.deepEqual @simpleTestDoc6.mix, { str: 'A string', bool: false }
      assert.property @simpleTestDoc6, 'buf'
      assert.equal @simpleTestDoc6.buf.toString(), 'abcdefg'
      assert.propertyVal @simpleTestDoc6, 'idx', 'Indexed'
      assert.property @simpleTestDoc6, '_id'
      assert.notProperty @simpleTestDoc6, '_ct'
      done()

  it 'should return an unencrypted version even if document already decrypted', (done) ->
    @encryptedSimpleTestDoc.decrypt (err) =>
      assert.equal err, null
      @encryptedSimpleTestDoc.decrypt (err) =>
        assert.equal err, null
        assert.propertyVal @encryptedSimpleTestDoc, 'text', 'Unencrypted text'
        assert.propertyVal @encryptedSimpleTestDoc, 'bool', true
        assert.propertyVal @encryptedSimpleTestDoc, 'num', 42
        assert.property @encryptedSimpleTestDoc, 'date'
        assert.equal @encryptedSimpleTestDoc.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
        assert.equal @encryptedSimpleTestDoc.id2.toString(), '5303e65d34e1e80d7a7ce212'
        assert.lengthOf @encryptedSimpleTestDoc.arr, 2
        assert.equal @encryptedSimpleTestDoc.arr[0], 'alpha'
        assert.equal @encryptedSimpleTestDoc.arr[1], 'bravo'
        assert.property @encryptedSimpleTestDoc, 'mix'
        assert.deepEqual @encryptedSimpleTestDoc.mix, { str: 'A string', bool: false }
        assert.property @encryptedSimpleTestDoc, 'buf'
        assert.equal @encryptedSimpleTestDoc.buf.toString(), 'abcdefg'
        assert.propertyVal @encryptedSimpleTestDoc, 'idx', 'Indexed'
        assert.property @encryptedSimpleTestDoc, '_id'
        assert.notProperty @encryptedSimpleTestDoc, '_ct'
        done()


describe 'document.decryptSync()', ->
  simpleTestDoc7 = null
  before (done) ->
    simpleTestDoc7 = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    simpleTestDoc7.encrypt (err) ->
      assert.equal err, null
      done()

  after (done) ->
    simpleTestDoc7.remove (err) ->
      assert.equal err, null
      done()

  it 'should return an unencrypted version', (done) ->
    simpleTestDoc7.decryptSync()
    assert.propertyVal simpleTestDoc7, 'text', 'Unencrypted text'
    assert.propertyVal simpleTestDoc7, 'bool', true
    assert.propertyVal simpleTestDoc7, 'num', 42
    assert.property simpleTestDoc7, 'date'
    assert.equal simpleTestDoc7.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
    assert.equal simpleTestDoc7.id2.toString(), '5303e65d34e1e80d7a7ce212'
    assert.lengthOf simpleTestDoc7.arr, 2
    assert.equal simpleTestDoc7.arr[0], 'alpha'
    assert.equal simpleTestDoc7.arr[1], 'bravo'
    assert.property simpleTestDoc7, 'mix'
    assert.deepEqual simpleTestDoc7.mix, { str: 'A string', bool: false }
    assert.property simpleTestDoc7, 'buf'
    assert.equal simpleTestDoc7.buf.toString(), 'abcdefg'
    assert.propertyVal simpleTestDoc7, 'idx', 'Indexed'
    assert.property simpleTestDoc7, '_id'
    assert.notProperty simpleTestDoc7, '_ct'
    done()

  it 'should return an unencrypted version even if document already decrypted', (done) ->
    simpleTestDoc7.decryptSync()
    assert.propertyVal simpleTestDoc7, 'text', 'Unencrypted text'
    assert.propertyVal simpleTestDoc7, 'bool', true
    assert.propertyVal simpleTestDoc7, 'num', 42
    assert.property simpleTestDoc7, 'date'
    assert.equal simpleTestDoc7.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
    assert.equal simpleTestDoc7.id2.toString(), '5303e65d34e1e80d7a7ce212'
    assert.lengthOf simpleTestDoc7.arr, 2
    assert.equal simpleTestDoc7.arr[0], 'alpha'
    assert.equal simpleTestDoc7.arr[1], 'bravo'
    assert.property simpleTestDoc7, 'mix'
    assert.deepEqual simpleTestDoc7.mix, { str: 'A string', bool: false }
    assert.property simpleTestDoc7, 'buf'
    assert.equal simpleTestDoc7.buf.toString(), 'abcdefg'
    assert.propertyVal simpleTestDoc7, 'idx', 'Indexed'
    assert.property simpleTestDoc7, '_id'
    assert.notProperty simpleTestDoc7, '_ct'
    done()


describe '"encryptedFields" option', ->
  it 'should encrypt fields iff they are in the passed in "encryptedFields" array even if those fields are indexed', (done) ->
    EncryptedFieldsModelSchema = mongoose.Schema
      text: type: String, index: true
      bool: type: Boolean
      num: type: Number

    EncryptedFieldsModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'EncryptedFields', encryptedFields: ['text', 'bool']

    FieldsEncryptedModel = mongoose.model 'Fields', EncryptedFieldsModelSchema

    fieldsEncryptedDoc = new FieldsEncryptedModel
      text: 'Unencrypted text'
      bool: false
      num: 43

    fieldsEncryptedDoc.encrypt (err) ->
      assert.equal err, null
      assert.equal fieldsEncryptedDoc.text, undefined
      assert.equal fieldsEncryptedDoc.bool, undefined
      assert.propertyVal fieldsEncryptedDoc, 'num', 43

      fieldsEncryptedDoc.decrypt (err) ->
        assert.equal err, null
        assert.equal fieldsEncryptedDoc.text, 'Unencrypted text'
        assert.equal fieldsEncryptedDoc.bool, false
        assert.propertyVal fieldsEncryptedDoc, 'num', 43
        done()

  it 'should override other options', (done) ->
    EncryptedFieldsOverrideModelSchema = mongoose.Schema
      text: type: String, index: true
      bool: type: Boolean
      num: type: Number

    EncryptedFieldsOverrideModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'EncryptedFieldsOverride', encryptedFields: ['text', 'bool'], excludeFromEncryption: ['bool']

    FieldsOverrideEncryptedModel = mongoose.model 'FieldsOverride', EncryptedFieldsOverrideModelSchema

    fieldsEncryptedDoc = new FieldsOverrideEncryptedModel
      text: 'Unencrypted text'
      bool: false
      num: 43

    fieldsEncryptedDoc.encrypt (err) ->
      assert.equal err, null
      assert.equal fieldsEncryptedDoc.text, undefined
      assert.equal fieldsEncryptedDoc.bool, undefined
      assert.propertyVal fieldsEncryptedDoc, 'num', 43

      fieldsEncryptedDoc.decrypt (err) ->
        assert.equal err, null
        assert.equal fieldsEncryptedDoc.text, 'Unencrypted text'
        assert.equal fieldsEncryptedDoc.bool, false
        assert.propertyVal fieldsEncryptedDoc, 'num', 43
        done()


describe '"excludeFromEncryption" option', ->
  it 'should encrypt all non-indexed fields except those in the passed-in "excludeFromEncryption" array', (done) ->
    ExcludeEncryptedModelSchema = mongoose.Schema
      text: type: String
      bool: type: Boolean
      num: type: Number
      idx: type: String, index: true

    ExcludeEncryptedModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'ExcludeEncrypted', excludeFromEncryption: ['num']

    ExcludeEncryptedModel = mongoose.model 'Exclude', ExcludeEncryptedModelSchema

    excludeEncryptedDoc = new ExcludeEncryptedModel
      text: 'Unencrypted text'
      bool: false
      num: 43
      idx: 'Indexed'

    excludeEncryptedDoc.encrypt (err) ->
      assert.equal err, null
      assert.equal excludeEncryptedDoc.text, undefined
      assert.equal excludeEncryptedDoc.bool, undefined
      assert.propertyVal excludeEncryptedDoc, 'num', 43
      assert.propertyVal excludeEncryptedDoc, 'idx', 'Indexed'

      excludeEncryptedDoc.decrypt (err) ->
        assert.equal err, null
        assert.equal excludeEncryptedDoc.text, 'Unencrypted text'
        assert.equal excludeEncryptedDoc.bool, false
        assert.propertyVal excludeEncryptedDoc, 'num', 43
        assert.propertyVal excludeEncryptedDoc, 'idx', 'Indexed'
        done()

describe '"decryptPostSave" option', ->
  before ->
    HighPerformanceModelSchema = mongoose.Schema
      text: type: String

    HighPerformanceModelSchema.plugin encrypt, secret: secret, decryptPostSave: false

    @HighPerformanceModel = mongoose.model 'HighPerformance', HighPerformanceModelSchema

  beforeEach (done) ->
    @doc = new @HighPerformanceModel
      text: 'Unencrypted text'
    done()

  afterEach (done) ->
    @HighPerformanceModel.remove (err) ->
      assert.equal err, null
      done()

  it 'saves encrypted fields correctly', (done) ->
    @doc.save (err) =>
      assert.equal err, null
      @HighPerformanceModel.find
        _id: @doc._id
        _ct: $exists: true
        text: $exists: false
      , (err, docs) ->
        assert.equal err, null
        assert.lengthOf docs, 1
        assert.propertyVal docs[0], 'text', 'Unencrypted text'
        done()

  it 'returns encrypted data after save', (done) ->
    @doc.save (err, savedDoc) ->
      assert.equal err, null
      assert.property savedDoc, '_ct', 'Document remains encrypted after save'
      assert.notProperty savedDoc, 'text'

      savedDoc.decrypt (err) ->
        assert.equal err, null
        assert.notProperty savedDoc, '_ct'
        assert.propertyVal savedDoc, 'text', 'Unencrypted text', 'Document can still be unencrypted'
        done()


describe 'Array EmbeddedDocument', ->
  describe 'when only child is encrypted', ->
    describe 'and parent does not have encryptedChildren plugin', ->
      before ->
        ChildModelSchema = mongoose.Schema
          text: type: String

        ChildModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey

        ParentModelSchema = mongoose.Schema
          text: type: String
          children: [ChildModelSchema]

        @ParentModel = mongoose.model 'Parent', ParentModelSchema
        @ChildModel = mongoose.model 'Child', ChildModelSchema

      beforeEach (done) ->
        @parentDoc = new @ParentModel
          text: 'Unencrypted text'

        childDoc = new @ChildModel
          text: 'Child unencrypted text'

        childDoc2 = new @ChildModel
          text: 'Second unencrypted text'

        @parentDoc.children.addToSet childDoc
        @parentDoc.children.addToSet childDoc2

        @parentDoc.save done

      after (done) ->
        @parentDoc.remove done

      describe 'document.save()', ->
        it 'should not have decrypted fields', ->
          assert.equal @parentDoc.children[0].text, undefined

        it 'should persist children as encrypted', (done) ->
          @ParentModel.find
            _id: @parentDoc._id
            'children._ct': $exists: true
            'children.text': $exists: false
          , (err, docs) ->
            assert.equal err, null
            assert.lengthOf docs, 1
            assert.propertyVal docs[0].children[0], 'text', 'Child unencrypted text'
            done()

      describe 'document.find()', ->
        it 'when parent doc found, should pass an unencrypted version of the embedded document to the callback', (done) ->
          @ParentModel.findById @parentDoc._id, (err, doc) ->
            assert.equal err, null
            assert.propertyVal doc, 'text', 'Unencrypted text'
            assert.isArray doc.children
            assert.isObject doc.children[0]
            assert.property doc.children[0], 'text', 'Child unencrypted text'
            assert.property doc.children[0], '_id'
            assert.notProperty doc.children[0], '_ct'
            done()

      describe 'tampering with child documents by swapping their ciphertext', ->
        it 'should not cause an error because embedded documents are not self-authenticated', (done) ->
          @ParentModel.findById(@parentDoc._id).lean().exec (err, doc) =>
            assert.equal err, null
            assert.isArray doc.children

            childDoc1CipherText = doc.children[0]._ct
            childDoc2CipherText = doc.children[1]._ct

            @ParentModel.update { _id: @parentDoc._id }
              , { $set : {'children.0._ct': childDoc2CipherText, 'children.1._ct': childDoc1CipherText } }
              , (err) =>
                assert.equal err, null
                @ParentModel.findById @parentDoc._id, (err, doc) ->
                  assert.equal err, null
                  assert.isArray doc.children
                  assert.property doc.children[0], 'text', 'Second unencrypted text', 'Ciphertext was swapped'
                  assert.property doc.children[1], 'text', 'Child unencrypted text', 'Ciphertext was swapped'
                  done()

    describe 'and parent has encryptedChildren plugin', ->
      before ->
        ChildModelSchema = mongoose.Schema
          text: type: String

        ChildModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey

        ParentModelSchema = mongoose.Schema
          text: type: String
          children: [ChildModelSchema]

        ParentModelSchema.plugin encrypt.encryptedChildren

        @ParentModel = mongoose.model 'ParentEC', ParentModelSchema
        @ChildModel = mongoose.model 'ChildOfECP', ChildModelSchema

      beforeEach (done) ->
        @parentDoc = new @ParentModel
          text: 'Unencrypted text'

        childDoc = new @ChildModel
          text: 'Child unencrypted text'

        childDoc2 = new @ChildModel
          text: 'Second unencrypted text'

        @parentDoc.children.addToSet childDoc
        @parentDoc.children.addToSet childDoc2

        @parentDoc.save done

      after (done) ->
        @parentDoc.remove done

      describe 'document.save()', ->
        it 'should have decrypted fields', ->
          assert.equal @parentDoc.children[0].text, 'Child unencrypted text'

        it 'should persist children as encrypted', (done) ->
          @ParentModel.find
            _id: @parentDoc._id
            'children._ct': $exists: true
            'children.text': $exists: false
          , (err, docs) ->
            assert.equal err, null
            assert.lengthOf docs, 1
            assert.propertyVal docs[0].children[0], 'text', 'Child unencrypted text'
            done()

      describe 'document.find()', ->
        it 'when parent doc found, should pass an unencrypted version of the embedded document to the callback', (done) ->
          @ParentModel.findById @parentDoc._id, (err, doc) ->
            assert.equal err, null
            assert.propertyVal doc, 'text', 'Unencrypted text'
            assert.isArray doc.children
            assert.isObject doc.children[0]
            assert.property doc.children[0], 'text', 'Child unencrypted text'
            assert.property doc.children[0], '_id'
            assert.notProperty doc.children[0], '_ct'
            done()

      describe 'tampering with child documents by swapping their ciphertext', ->
        it 'should not cause an error because embedded documents are not self-authenticated', (done) ->
          @ParentModel.findById(@parentDoc._id).lean().exec (err, doc) =>
            assert.equal err, null
            assert.isArray doc.children

            childDoc1CipherText = doc.children[0]._ct
            childDoc2CipherText = doc.children[1]._ct

            @ParentModel.update { _id: @parentDoc._id }
              , { $set : {'children.0._ct': childDoc2CipherText, 'children.1._ct': childDoc1CipherText } }
              , (err) =>
                assert.equal err, null
                @ParentModel.findById @parentDoc._id, (err, doc) ->
                  assert.equal err, null
                  assert.isArray doc.children
                  assert.property doc.children[0], 'text', 'Second unencrypted text', 'Ciphertext was swapped'
                  assert.property doc.children[1], 'text', 'Child unencrypted text', 'Ciphertext was swapped'
                  done()

    describe 'when child is encrypted and authenticated', ->
      before ->
        ChildModelSchema = mongoose.Schema
          text: type: String

        ChildModelSchema.plugin encrypt,
          encryptionKey: encryptionKey
          signingKey: signingKey

        ParentModelSchema = mongoose.Schema
          text: type: String
          children: [ChildModelSchema]

        ParentModelSchema.plugin encrypt,
          encryptionKey: encryptionKey
          signingKey: signingKey
          encryptedFields: []
          additionalAuthenticatedFields: ['children']

        @ParentModel = mongoose.model 'ParentWithAuth', ParentModelSchema
        @ChildModel = mongoose.model 'ChildWithAuth', ChildModelSchema

      beforeEach (done) ->
        @parentDoc = new @ParentModel
          text: 'Unencrypted text'

        childDoc = new @ChildModel
          text: 'Child unencrypted text'

        childDoc2 = new @ChildModel
          text: 'Second unencrypted text'

        @parentDoc.children.addToSet childDoc
        @parentDoc.children.addToSet childDoc2

        @parentDoc.save done

      after (done) ->
        @parentDoc.remove done

      it 'should persist children as encrypted after removing a child', (done) ->
        @ParentModel.findById @parentDoc._id, (err, doc) =>
          return done(err) if err
          assert.ok doc, 'should have found doc with encrypted children'

          doc.children.id(doc.children[1]._id).remove()

          doc.save (err) =>
            return done(err) if err

            @ParentModel.find
              _id: @parentDoc._id
              'children._ct': $exists: true
              'children.text': $exists: false
            , (err, docs) ->
              return done(err) if err
              assert.ok doc, 'should have found doc with encrypted children'
              assert.equal doc.children.length, 1

              done()

      it 'should persist children as encrypted after adding a child', (done) ->
        @ParentModel.findById @parentDoc._id, (err, doc) =>
          return done(err) if err
          assert.ok doc, 'should have found doc with encrypted children'

          doc.children.addToSet text: 'new child'

          doc.save (err) =>
            return done(err) if err

            @ParentModel.findById @parentDoc._id
            .exec (err, doc) =>
              return done(err) if err
              assert.ok doc, 'should have found doc with encrypted children'
              assert.equal doc.children.length, 3

              done()

  describe 'when child and parent are encrypted', ->
    before ->
      ChildModelSchema = mongoose.Schema
        text: type: String

      ChildModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey

      ParentModelSchema = mongoose.Schema
        text: type: String
        children: [ChildModelSchema]

      ParentModelSchema.plugin encrypt,
        encryptionKey: encryptionKey
        signingKey: signingKey
        encryptedFields: ['text']
        additionalAuthenticatedFields: ['children']

      @ParentModel = mongoose.model 'ParentBoth', ParentModelSchema
      @ChildModel = mongoose.model 'ChildBoth', ChildModelSchema

    beforeEach (done) ->
      @parentDoc = new @ParentModel
        text: 'Unencrypted text'

      childDoc = new @ChildModel
        text: 'Child unencrypted text'

      childDoc2 = new @ChildModel
        text: 'Second unencrypted text'

      @parentDoc.children.addToSet childDoc
      @parentDoc.children.addToSet childDoc2

      @parentDoc.save done

    after (done) ->
      @parentDoc.remove done

    describe 'document.save()', ->
      it 'should have decrypted fields on parent', ->
        assert.equal @parentDoc.text, 'Unencrypted text'

      it 'should have decrypted fields', ->
        assert.equal @parentDoc.children[0].text, 'Child unencrypted text'

      it 'should persist children as encrypted', (done) ->
        @ParentModel.find
          _id: @parentDoc._id
          'children._ct': $exists: true
          'children.text': $exists: false
        , (err, docs) ->
          assert.equal err, null
          assert.lengthOf docs, 1
          assert.propertyVal docs[0].children[0], 'text', 'Child unencrypted text'
          done()

    describe 'document.find()', ->
      it 'when parent doc found, should pass an unencrypted version of the embedded document to the callback', (done) ->
        @ParentModel.findById @parentDoc._id
        , (err, doc) ->
          assert.equal err, null
          assert.propertyVal doc, 'text', 'Unencrypted text'
          assert.isArray doc.children
          assert.isObject doc.children[0]
          assert.property doc.children[0], 'text', 'Child unencrypted text'
          assert.property doc.children[0], '_id'
          assert.notProperty doc.children[0], '_ct'
          done()

    describe 'when child field is in additionalAuthenticatedFields on parent and child documents are tampered with by swapping their ciphertext', ->
      it 'should pass an error', (done) ->
        @ParentModel.findById(@parentDoc._id).lean().exec (err, doc) =>
          assert.equal err, null
          assert.isArray doc.children

          childDoc1CipherText = doc.children[0]._ct
          childDoc2CipherText = doc.children[1]._ct

          @ParentModel.update { _id: @parentDoc._id }
            , { $set : {'children.0._ct': childDoc2CipherText, 'children.1._ct': childDoc1CipherText } }
            , (err) =>
              assert.equal err, null
              @ParentModel.findById @parentDoc._id, (err, doc) ->
                assert.ok err, 'There was an error'
                assert.propertyVal err, 'message', 'Authentication failed'
                done()

  describe 'when entire parent is encrypted', ->
    before ->
      ParentModelSchema = mongoose.Schema
        text: type: String
        children: [text: type: String]

      ParentModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey

      @ParentModel = mongoose.model 'ParentEntire', ParentModelSchema

    beforeEach (done) ->
      @parentDoc = new @ParentModel
        text: 'Unencrypted text'
        children: [text: 'Child unencrypted text']

      @parentDoc.save done

    after (done) ->
      @parentDoc.remove done

    describe 'document.save()', ->
      it 'should have decrypted fields in document passed to call back', ->
        assert.equal @parentDoc.text, 'Unencrypted text'
        assert.equal @parentDoc.children[0].text, 'Child unencrypted text'

      it 'should persist the entire document as encrypted', (done) ->
        @ParentModel.find
          _id: @parentDoc._id
          '_ct': $exists: true
          'children': $exists: false
          'children.text': $exists: false
        , (err, docs) ->
          assert.equal err, null
          assert.lengthOf docs, 1
          assert.propertyVal docs[0], 'text', 'Unencrypted text'
          assert.propertyVal docs[0].children[0], 'text', 'Child unencrypted text'
          done()

    describe 'document.find()', ->
      it 'when parent doc found, should pass an unencrypted version of the embedded document to the callback', (done) ->
        @ParentModel.findById @parentDoc._id, (err, doc) ->
          assert.equal err, null
          assert.propertyVal doc, 'text', 'Unencrypted text'
          assert.isArray doc.children
          assert.isObject doc.children[0]
          assert.property doc.children[0], 'text', 'Child unencrypted text'
          assert.property doc.children[0], '_id'
          assert.notProperty doc.children[0], '_ct'
          done()

  describe 'Encrypted embedded document when parent has validation error and doesnt have encryptedChildren plugin', ->
    before ->
      ChildModelSchema = mongoose.Schema
        text: type: String

      ChildModelSchema.plugin encrypt,
        encryptionKey: encryptionKey, signingKey: signingKey
        encryptedFields: ['text']

      ParentModelSchema = mongoose.Schema
        text: type: String
        children: [ChildModelSchema]

      ParentModelSchema.pre 'validate', (next) ->
        @invalidate 'text', 'invalid', this.text
        next()

      @ParentModel2 = mongoose.model 'ParentWithoutPlugin', ParentModelSchema
      @ChildModel2 = mongoose.model 'ChildAgain', ChildModelSchema

    it 'should return unencrypted embedded documents', (done) ->
      doc = new @ParentModel2
        text: 'here it is'
        children: [{text: 'Child unencrypted text'}]
      doc.save (err) ->
        assert.ok err, 'There should be a validation error'
        assert.propertyVal doc, 'text', 'here it is'
        assert.isArray doc.children
        assert.property doc.children[0], '_id'
        assert.notProperty doc.children[0], '_ct'
        assert.property doc.children[0], 'text', 'Child unencrypted text'
        done()

  describe 'Encrypted embedded document when parent has validation error and has encryptedChildren plugin', ->
    before ->
      ChildModelSchema = mongoose.Schema
        text: type: String

      ChildModelSchema.plugin encrypt,
        encryptionKey: encryptionKey, signingKey: signingKey
        encryptedFields: ['text']

      @ParentModelSchema = mongoose.Schema
        text: type: String
        children: [ChildModelSchema]

      @ParentModelSchema.pre 'validate', (next) ->
          @invalidate 'text', 'invalid', this.text
          next()

      @sandbox = sinon.sandbox.create()
      @sandbox.stub console, 'warn'
      @sandbox.spy @ParentModelSchema, 'post'

      @ParentModelSchema.plugin encrypt.encryptedChildren

      @ParentModel2 = mongoose.model 'ParentWithPlugin', @ParentModelSchema
      @ChildModel2 = mongoose.model 'ChildOnceMore', ChildModelSchema

    after ->
      @sandbox.restore()

    it 'should return unencrypted embedded documents', (done) ->
      doc = new @ParentModel2
        text: 'here it is'
        children: [{text: 'Child unencrypted text'}]
      doc.save (err) ->
        assert.ok err, 'There should be a validation error'
        assert.propertyVal doc, 'text', 'here it is'
        assert.isArray doc.children
        assert.property doc.children[0], '_id'
        assert.notProperty doc.children[0], '_ct'
        assert.property doc.children[0], 'text', 'Child unencrypted text'
        done()

  describe 'Encrypted embedded document when parent has both encrypt and encryptedChildren plugins', ->
    before ->
      ChildModelSchema = mongoose.Schema
        text: type: String

      ChildModelSchema.plugin encrypt,
        encryptionKey: encryptionKey, signingKey: signingKey
        encryptedFields: ['text']

      ParentModelSchema = mongoose.Schema
        text: type: String
        children: [ChildModelSchema]
        encryptedText: type: String

      ParentModelSchema.plugin encrypt.encryptedChildren
      ParentModelSchema.plugin encrypt,
        encryptionKey: encryptionKey, signingKey: signingKey
        encryptedFields: ['encryptedText']

      @ParentModel2 = mongoose.model 'ParentWithBothPlugins', ParentModelSchema
      @ChildModel2 = mongoose.model 'Child2', ChildModelSchema

    describe 'when parent document has validation error', =>
      before ->
        @invalidDoc = new @ParentModel2
          text: 'here it is'
          encryptedText: 'here is more'
          children: [{text: 'Child unencrypted text'}]
        @invalidDoc.invalidate 'text', 'invalid', this.text

      it 'should return unencrypted parent and embedded documents', (done) ->
        doc = @invalidDoc
        @invalidDoc.save (err) ->
          assert.ok err, 'There should be a validation error'
          assert.propertyVal doc, 'text', 'here it is'
          assert.propertyVal doc, 'encryptedText', 'here is more'
          assert.isArray doc.children
          assert.property doc.children[0], '_id'
          assert.notProperty doc.children[0], '_ct'
          assert.property doc.children[0], 'text', 'Child unencrypted text'
          done()

    describe 'when parent document does not have validation error', =>
      it 'should return unencrypted parent and embedded documents', (done) ->
        doc = new @ParentModel2
          text: 'here it is'
          encryptedText: 'here is more'
          children: [{text: 'Child unencrypted text'}]
        doc.save (err) ->
          assert.equal err, null
          assert.propertyVal doc, 'text', 'here it is'
          assert.isArray doc.children
          assert.property doc.children[0], '_id'
          assert.notProperty doc.children[0], '_ct'
          assert.property doc.children[0], 'text', 'Child unencrypted text'
          done()


describe 'document.sign()', ->
  before (done) ->
    @testDoc = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    @testDoc.sign (err) ->
      assert.equal err, null
      done()

  after (done) ->
    @testDoc.remove (err) ->
      assert.equal err, null
      done()

  it 'should return an signed version', (done) ->
    assert.property @testDoc, '_ac'
    @initialAC = @testDoc._ac
    done()

  it 'should use the same signature if signed twice', (done) ->
    @testDoc.sign (err) =>
      assert.equal err, null
      assert.property @testDoc, '_ac'
      assert.ok bufferEqual(@testDoc._ac, @initialAC)
      done()

describe 'document.sign() on encrypted document', ->
  before (done) ->
    @testDoc = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    @testDoc.encrypt (err) =>
      assert.equal err, null
      @testDoc.sign (err) ->
        assert.equal err, null
        done()

  after (done) ->
    @testDoc.remove (err) ->
      assert.equal err, null
      done()

  it 'should return an signed version', (done) ->
    assert.property @testDoc, '_ac'
    @initialAC = @testDoc._ac
    done()

  it 'should use the same signature if signed twice', (done) ->
    @testDoc.sign (err) =>
      assert.equal err, null
      assert.property @testDoc, '_ac'
      assert.ok bufferEqual(@testDoc._ac, @initialAC)
      done()


describe 'document.authenticateSync()', ->
  @testDocAS = null
  beforeEach (done) ->
    @testDocAS = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    @testDocAS.sign (err) ->
      assert.equal err, null
      done()

  afterEach (done) ->
    @testDocAS.remove (err) ->
      assert.equal err, null
      done()

  it 'should return without an error if document is signed and unmodified', ->
    assert.doesNotThrow =>
      @testDocAS.authenticateSync()

  it 'should not throw error if a non-authenticated field has been modified', ->
    @testDocAS.num = 48
    assert.doesNotThrow =>
      @testDocAS.authenticateSync()


  it 'should throw error if _id has been modified', ->
    @testDocAS._id = new mongoose.Types.ObjectId()
    assert.throws =>
      @testDocAS.authenticateSync()

  it 'should throw error if _ac has been modified randomly', ->
    @testDocAS._ac = new Buffer 'some random buffer'
    assert.throws =>
      @testDocAS.authenticateSync()

  it 'should throw error if _ac has been modified to have authenticated fields = []', ->
    acWithoutAFLength = encrypt.AAC_LENGTH + encrypt.VERSION_LENGTH
    blankArrayBuffer = new Buffer JSON.stringify([])
    bareBuffer = new Buffer acWithoutAFLength
    bareBuffer.copy(@testDocAS._ac, 0, 0, acWithoutAFLength)
    @testDocAS._ac = Buffer.concat [bareBuffer, blankArrayBuffer]
    assert.throws =>
      @testDocAS.authenticateSync()

  it 'should throw error if _ac has been modified to have no authenticated fields section', ->
    acWithoutAFLength = encrypt.AAC_LENGTH + encrypt.VERSION_LENGTH
    poisonBuffer = new Buffer acWithoutAFLength
    poisonBuffer.copy(@testDocAS._ac, 0, 0, acWithoutAFLength)
    @testDocAS._ac = poisonBuffer
    assert.throws =>
      @testDocAS.authenticateSync()

  it 'should throw error if _ac has been set to null', ->
    @testDocAS._ac = null
    assert.throws =>
      @testDocAS.authenticateSync()

  it 'should throw error if _ac has been set to undefined', ->
    @testDocAS._ac = undefined
    assert.throws =>
      @testDocAS.authenticateSync()


  it 'should throw error if _ct has been added', ->
    @testDocAS._ct = new Buffer('Poison')
    assert.throws =>
      @testDocAS.authenticateSync()


describe 'document.authenticateSync() on encrypted documents', ->
  @testDocAS = null
  beforeEach (done) ->
    @testDocAS = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    @testDocAS.encrypt (err) =>
      assert.equal err, null
      @testDocAS.sign (err) ->
        assert.equal err, null
        done()

  afterEach (done) ->
    @testDocAS.remove (err) ->
      assert.equal err, null
      done()

  it 'should return without an error if document is signed and unmodified', ->
    assert.doesNotThrow =>
      @testDocAS.authenticateSync()

  it 'should not throw error if a non-authenticated field has been modified', ->
    @testDocAS.num = 48
    assert.doesNotThrow =>
      @testDocAS.authenticateSync()

  it 'should throw error if _id has been modified', ->
    @testDocAS._id = new mongoose.Types.ObjectId()
    assert.throws =>
      @testDocAS.authenticateSync()

  it 'should throw error if _ct has been modified', ->
    @testDocAS._ct = new Buffer('Poison')
    assert.throws =>
      @testDocAS.authenticateSync()


describe 'document.authenticate()', -> # these are mostly covered in .authenticateSync. this checks the errors more closely
  @testDocA = null
  beforeEach (done) ->
    @testDocA = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    @testDocA.sign (err) ->
      assert.equal err, null
      done()

  afterEach (done) ->
    @testDocA.remove (err) ->
      assert.equal err, null
      done()

  it 'should pass error if _ac has been modified to have authenticated fields = []', (done) ->
    acWithoutAFLength = encrypt.AAC_LENGTH + encrypt.VERSION_LENGTH
    blankArrayBuffer = new Buffer JSON.stringify([])
    bareBuffer = new Buffer acWithoutAFLength
    bareBuffer.copy(@testDocA._ac, 0, 0, acWithoutAFLength)
    @testDocA._ac = Buffer.concat [bareBuffer, blankArrayBuffer]
    @testDocA.authenticate (err) ->
      assert.ok err
      assert.equal err.message, '_id must be in array of fields to authenticate'
      done()

  it 'should pass error if _ac has been modified to have no authenticated fields section', (done)  ->
    acWithoutAFLength = encrypt.AAC_LENGTH + encrypt.VERSION_LENGTH
    poisonBuffer = new Buffer acWithoutAFLength
    poisonBuffer.copy(@testDocA._ac, 0, 0, acWithoutAFLength)
    @testDocA._ac = poisonBuffer
    @testDocA.authenticate (err) ->
      assert.ok err
      assert.equal err.message, '_ac is too short and has likely been cut off or modified'
      done()


describe 'Tampering with an encrypted document', ->
  before (done) ->
    @testDoc = new BasicEncryptedModel
      text: 'Unencrypted text'
      bool: true
      num: 42
      date: new Date '2014-05-19T16:39:07.536Z'
      id2: '5303e65d34e1e80d7a7ce212'
      arr: ['alpha', 'bravo']
      mix: { str: 'A string', bool: false }
      buf: new Buffer 'abcdefg'
      idx: 'Indexed'

    @testDoc2 = new BasicEncryptedModel
      text: 'Unencrypted text2'
      bool: true
      num: 46
      date: new Date '2014-05-19T16:22:07.536Z'
      id2: '5303e65d34e1e80d7a7ce210'
      arr: ['alpha', 'dela']
      mix: { str: 'A strings', bool: true }
      buf: new Buffer 'dssd'
      idx: 'Indexed again'

    @testDoc.save (err) =>
      assert.equal err, null
      @testDoc2.save (err) =>
        assert.equal err, null
        done()

  after (done) ->
    @testDoc.remove (err) =>
      assert.equal err, null
      @testDoc2.remove (err) ->
        assert.equal err, null
        done()

  it 'should throw an error on .find() if _ct is swapped from another document', (done) ->
    BasicEncryptedModel.findOne(_id: @testDoc2._id).lean().exec (err, doc2) =>
      assert.equal err, null
      ctForSwap = doc2._ct.buffer
      BasicEncryptedModel.update({_id: @testDoc._id}, {$set: _ct: doc2._ct}).exec (err, raw) =>
        n = raw.n || raw
        assert.equal err, null
        assert.equal n, 1
        BasicEncryptedModel.findOne(_id: @testDoc._id).exec (err, doc) =>
          assert.ok err
          done()


describe 'additionalAuthenticatedFields option', ->
  AuthenticatedFieldsModelSchema = mongoose.Schema
    text: type: String
    bool: type: Boolean
    num: type: Number

  AuthenticatedFieldsModelSchema.plugin encrypt,
    encryptionKey: encryptionKey
    signingKey: signingKey
    collectionId: 'AuthenticatedFields'
    encryptedFields: ['text']
    additionalAuthenticatedFields: ['bool']

  AuthenticatedFieldsModel = mongoose.model 'AuthenticatedFields', AuthenticatedFieldsModelSchema

  @testDocAF = null
  beforeEach (done) ->
    @testDocAF = new AuthenticatedFieldsModel
      text: 'Unencrypted text'
      bool: true
      num: 42

    @testDocAF.save (err) ->
      assert.equal err, null
      done()

  afterEach (done) ->
    @testDocAF.remove (err) ->
      assert.equal err, null
      done()

  it 'find should succeed if document is unmodified', (done) ->
    AuthenticatedFieldsModel.findById @testDocAF._id, (err, doc) =>
      assert.equal err, null
      done()

  it 'find should succeed if non-authenticated field is modified directly', (done) ->
    AuthenticatedFieldsModel.update({_id: @testDocAF._id}, {$set: num: 48}).exec (err, raw) =>
      n = raw.n || raw
      assert.equal err, null
      assert.equal n, 1
      AuthenticatedFieldsModel.findById @testDocAF._id, (err, doc) =>
        assert.equal err, null
        assert.propertyVal doc, 'num', 48
        done()

  it 'find should fail if non-authenticated field is modified directly', (done) ->
    AuthenticatedFieldsModel.update({_id: @testDocAF._id}, {$set: bool: false}).exec (err, raw) =>
      n = raw.n || raw
      assert.equal err, null
      assert.equal n, 1
      AuthenticatedFieldsModel.findById @testDocAF._id, (err, doc) =>
        assert.ok err, 'There was an error'
        assert.propertyVal err, 'message', 'Authentication failed'
        done()

describe '"requireAuthenticationCode" option', ->
  describe 'set to false and plugin used with existing collection without a migration', ->

    LessSecureSchema = mongoose.Schema
      text: type: String
      bool: type: Boolean
      num: type: Number

    LessSecureSchema.plugin encrypt,
      encryptionKey: encryptionKey
      signingKey: signingKey
      requireAuthenticationCode: false

    LessSecureModel = mongoose.model 'LessSecure', LessSecureSchema

    before (done) ->
      plainDoc =
        text: 'Plain'
        bool: true

      plainDoc2 =
        bool: false
        num: 33

      LessSecureModel.collection.insert [plainDoc, plainDoc2], (err, raw) =>
        assert.equal err, null
        docs = raw.ops || raw
        @docId = docs[0]._id
        @doc2Id = docs[1]._id
        done()

    after (done) ->
      LessSecureModel.remove {}, (err) ->
        assert.equal err, null
        done()

    it 'should just work', (done) ->
      LessSecureModel.findById @docId, (err, unmigratedDoc1) =>
        assert.equal err, null, 'There should be no authentication error'
        assert.propertyVal unmigratedDoc1, 'text', 'Plain'
        assert.propertyVal unmigratedDoc1, 'bool', true
        unmigratedDoc1.save (err) =>
          assert.equal err, null

          LessSecureModel.findById(@docId).lean().exec (err, rawDoc1) =>
            assert.equal err, null
            assert.notProperty rawDoc1, 'text', 'raw in db shouldnt show encrypted properties'
            assert.notProperty rawDoc1, 'bool'
            assert.property rawDoc1, '_ct', 'raw in db should have ciphertext'
            assert.property rawDoc1, '_ac', 'raw in db should have authentication code'

            LessSecureModel.findById @docId, (err, unmigratedDoc1) =>
              assert.equal err, null
              assert.propertyVal unmigratedDoc1, 'text', 'Plain'
              assert.propertyVal unmigratedDoc1, 'bool', true
              done()


describe 'period in field name in options', ->
  it 'should encrypt nested fields with dot notation', (done) ->
    NestedModelSchema = mongoose.Schema
      nest:
        secretBird: type: String
        secretBird2: type: String
        publicBird: type: String

    NestedModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'EncryptedFields', encryptedFields: ['nest.secretBird', 'nest.secretBird2'], additionalAuthenticatedFields: ['nest.publicBird']

    NestedModel = mongoose.model 'Nested', NestedModelSchema

    nestedDoc = new NestedModel
      nest:
        secretBird: 'Unencrypted text'
        secretBird2: 'Unencrypted text 2'
        publicBird: 'Unencrypted text 3'

    nestedDoc.encrypt (err) ->
      assert.equal err, null
      assert.equal nestedDoc.nest.secretBird, undefined
      assert.equal nestedDoc.nest.secretBird2, undefined
      assert.equal nestedDoc.nest.publicBird, 'Unencrypted text 3'

      nestedDoc.decrypt (err) ->
        assert.equal err, null
        assert.equal nestedDoc.nest.secretBird, 'Unencrypted text'
        assert.equal nestedDoc.nest.secretBird2, 'Unencrypted text 2'
        assert.equal nestedDoc.nest.publicBird, 'Unencrypted text 3'
        done()

  it 'should encrypt nested fields with dot notation two layers deep', (done) ->
    NestedModelSchema = mongoose.Schema
      nest:
        secretBird:
          topSecretEgg: type: String

    NestedModelSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey, collectionId: 'EncryptedFields', encryptedFields: ['nest.secretBird.topSecretEgg']

    NestedModel = mongoose.model 'NestedNest', NestedModelSchema

    nestedDoc = new NestedModel
      nest: secretBird: topSecretEgg: 'Unencrypted text'

    nestedDoc.encrypt (err) ->
      assert.equal err, null
      assert.equal nestedDoc.nest.secretBird.topSecretEgg, undefined

      nestedDoc.decrypt (err) ->
        assert.equal err, null
        assert.equal nestedDoc.nest.secretBird.topSecretEgg, 'Unencrypted text'
        done()

describe 'saving same authenticated document twice asynchronously', ->

  TwoFieldAuthModel = null

  TwoFieldAuthSchema = mongoose.Schema
    text: type: String
    num: type: Number

  TwoFieldAuthSchema.plugin encrypt,
    secret: secret
    encryptedFields: []
    additionalAuthenticatedFields: ['text', 'num']

  TwoFieldAuthModel = mongoose.model 'TwoField', TwoFieldAuthSchema

  before (done) ->
    @testDoc = new TwoFieldAuthModel
      text: 'Unencrypted text'
      num: 42
    @testDoc.save(done)

  it 'should not cause errors, and the second save to authenticated fields should override the first in order (a transaction is forced)', (done) ->
    TwoFieldAuthModel.findOne {_id: @testDoc._id}, (err, doc) =>
      assert.equal err, null
      doc.text = "Altered text";

      TwoFieldAuthModel.findOne {_id: @testDoc._id}, (err, docAgain) =>
        assert.equal err, null

        docAgain.num = 55

        doc.save (err) =>
          assert.equal err, null

          docAgain.save (err) =>
            assert.equal err, null

            TwoFieldAuthModel.find {_id: @testDoc._id}, (err, finalDocs) =>
              assert.equal err, null
              assert.lengthOf finalDocs, 1
              assert.propertyVal finalDocs[0], 'text', 'Unencrypted text'
              assert.propertyVal finalDocs[0], 'num', 55
              done()




describe 'migrations', ->
  describe 'migrateToA static model method', ->
    describe 'on collection encrypted with previous version', ->
      OriginalSchemaObject =
        text: type: String
        bool: type: Boolean
        num: type: Number
        date: type: Date
        id2: type: mongoose.Schema.Types.ObjectId
        arr: [ type: String ]
        mix: type: mongoose.Schema.Types.Mixed
        buf: type: Buffer
        idx: type: String, index: true
        unencryptedText: type: String

      OriginalSchema = mongoose.Schema OriginalSchemaObject

      OriginalSchema.plugin encrypt,
        encryptionKey: encryptionKey
        signingKey: signingKey
        excludeFromEncryption: ['unencryptedText']

      OriginalModel = mongoose.model 'Old', OriginalSchema

      MigrationSchema = mongoose.Schema OriginalSchemaObject

      MigrationSchema.plugin encrypt.migrations,  # add migrations plugin
        encryptionKey: encryptionKey
        signingKey: signingKey
        excludeFromEncryption: ['unencryptedText']
        collectionId: 'Old'

      MigrationModel = mongoose.model 'Migrate', MigrationSchema, 'olds' # same collection as original model

      before (done) ->
        # this buffer comes from a doc saved with the version of mongoose-encrypt without authentication
        bufferEncryptedWithOldVersion = new Buffer JSON.parse "[130,155,222,38,127,97,89,38,0,26,14,38,24,35,147,38,119,60,112,58,75,92,205,170,72,4,149,87,48,23,162,92,92,59,16,76,124,225,243,209,155,91,213,99,95,49,110,233,229,165,6,128,162,246,117,146,209,170,138,43,74,172,159,212,237,4,0,112,55,3,132,46,80,183,66,236,176,58,221,47,153,248,211,71,76,148,215,217,66,169,77,11,133,134,128,50,166,231,164,110,136,95,207,187,179,101,208,230,6,77,125,49,211,24,210,160,99,166,76,180,183,57,179,129,85,6,64,34,210,114,217,176,49,50,122,192,27,189,146,125,212,133,40,100,7,190,2,237,166,89,131,31,197,225,211,79,205,208,185,209,252,151,159,6,58,140,122,151,99,241,211,129,148,105,33,198,18,118,235,202,55,7,20,138,27,31,173,181,170,97,15,193,174,243,100,175,135,164,154,239,158,217,205,109,165,84,38,37,2,55,5,67,20,82,247,116,167,67,250,84,91,204,244,92,217,86,177,71,174,244,136,169,57,140,226,85,239,160,128,10]"
        docEncryptedWithOldVersion = _ct: bufferEncryptedWithOldVersion

        bufferEncryptedWithOldVersion2 = new Buffer JSON.parse "[54,71,156,112,212,239,137,202,17,196,176,29,93,28,27,150,212,76,5,153,218,234,68,160,236,158,155,221,186,180,72,0,254,236,240,38,167,173,132,20,235,170,98,78,16,221,86,253,121,49,152,28,40,152,216,45,223,201,241,68,85,1,52,2,6,25,25,120,29,75,246,117,164,103,252,40,16,163,45,240]"
        docEncryptedWithOldVersion2 =
          _ct: bufferEncryptedWithOldVersion2
          unencryptedText: 'Never was encrypted'

        OriginalModel.collection.insert [docEncryptedWithOldVersion, docEncryptedWithOldVersion2], (err, raw) =>
          assert.equal err, null
          docs = raw.ops || raw
          @docId = docs[0]._id
          @doc2Id = docs[1]._id
          OriginalModel.findById @docId, (err, doc) ->
            assert.ok err, 'There should be an authentication error before migration'
            assert.propertyVal err, 'message', 'Authentication code missing'
            done()

      after (done) ->
        OriginalModel.remove {}, (err) ->
          assert.equal err, null
          done()

      it 'should transform existing documents in collection such that they work with plugin version A', (done) ->
        MigrationModel.migrateToA (err) =>
          assert.equal err, null
          OriginalModel.findById @docId, (err, migratedDoc1) =>
            assert.equal err, null, 'There should be no authentication error after migration'
            assert.propertyVal migratedDoc1, 'text', 'Unencrypted text'
            assert.propertyVal migratedDoc1, 'bool', true
            assert.propertyVal migratedDoc1, 'num', 42
            assert.property migratedDoc1, 'date'
            assert.equal migratedDoc1.date.toString(), new Date("2014-05-19T16:39:07.536Z").toString()
            assert.equal migratedDoc1.id2.toString(), '5303e65d34e1e80d7a7ce212'
            assert.lengthOf migratedDoc1.arr, 2
            assert.equal migratedDoc1.arr[0], 'alpha'
            assert.equal migratedDoc1.arr[1], 'bravo'
            assert.property migratedDoc1, 'mix'
            assert.deepEqual migratedDoc1.mix, { str: 'A string', bool: false }
            assert.property migratedDoc1, 'buf'
            assert.equal migratedDoc1.buf.toString(), 'abcdefg'
            assert.property migratedDoc1, '_id'
            assert.notProperty migratedDoc1, '_ct'
            assert.notProperty migratedDoc1, '_ac'

            OriginalModel.findById @doc2Id, (err, migratedDoc2) =>
              assert.equal err, null, 'There should be no authentication error after migration'
              assert.propertyVal migratedDoc2, 'text', 'Some other text'
              assert.propertyVal migratedDoc2, 'bool', false
              assert.propertyVal migratedDoc2, 'num', 40
              assert.propertyVal migratedDoc2, 'unencryptedText', 'Never was encrypted'
              done()

    describe 'on previously unencrypted collection', ->
      schemaObject =
        text: type: String
        bool: type: Boolean
        num: type: Number

      PreviouslyUnencryptedSchema = mongoose.Schema schemaObject

      PreviouslyUnencryptedSchema.plugin encrypt.migrations,
        encryptionKey: encryptionKey
        signingKey: signingKey

      PreviouslyUnencryptedModel = mongoose.model 'FormerlyPlain', PreviouslyUnencryptedSchema


      before (done) ->
        plainDoc =
          text: 'Plain'
          bool: true

        plainDoc2 =
          bool: false
          num: 33

        PreviouslyUnencryptedModel.collection.insert [plainDoc, plainDoc2], (err, raw) =>
          assert.equal err, null
          docs = raw.ops || raw
          @docId = docs[0]._id
          @doc2Id = docs[1]._id
          done()

      after (done) ->
        PreviouslyUnencryptedModel.remove {}, (err) ->
          assert.equal err, null
          done()

      it 'should transform documents in an unencrypted collection such that they are signed and encrypted and work with plugin version A', (done) ->
        PreviouslyUnencryptedModel.migrateToA (err) =>
          assert.equal err, null

          # add back in middleware
          PreviouslyUnencryptedSchemaMigrated = mongoose.Schema schemaObject
          PreviouslyUnencryptedSchemaMigrated.plugin encrypt,
            encryptionKey: encryptionKey
            signingKey: signingKey
            _suppressDuplicatePluginError: true # to allow for this test
            collectionId: 'FormerlyPlain'
          PreviouslyUnencryptedModelMigrated = mongoose.model 'FormerlyPlain2', PreviouslyUnencryptedSchemaMigrated, 'formerlyplains'

          PreviouslyUnencryptedModelMigrated.findById(@docId).lean().exec (err, migratedDoc) =>
            assert.equal err, null
            assert.notProperty migratedDoc, 'text', 'Should be encrypted in db after migration'
            assert.notProperty migratedDoc, 'bool'
            assert.property migratedDoc, '_ac'
            assert.property migratedDoc, '_ct', 'Should have ciphertext in raw db after migration'


            PreviouslyUnencryptedModelMigrated.findById @docId, (err, migratedDoc) =>
              assert.equal err, null, 'There should be no authentication error after migrated'
              assert.propertyVal migratedDoc, 'text', 'Plain'
              assert.propertyVal migratedDoc, 'bool', true

              migratedDoc.save (err) =>
                assert.equal err, null

                PreviouslyUnencryptedModelMigrated.findById(@docId).lean().exec (err, migratedDoc) =>
                  assert.equal err, null
                  assert.notProperty migratedDoc, 'text', 'Should be encrypted in raw db after saved'
                  assert.notProperty migratedDoc, 'bool'
                  assert.property migratedDoc, '_ac'
                  assert.property migratedDoc, '_ct', 'Should have ciphertext in raw db after saved'
                  done()

  describe 'migrateSubDocsToA static model method', ->
    describe 'on collection where subdocs encrypted with previous version', ->


      before (done) ->
        OriginalChildSchema = mongoose.Schema
          text: type: String

        OriginalChildSchema.plugin encrypt, encryptionKey: encryptionKey, signingKey: signingKey

        OriginalParentSchema = mongoose.Schema
          text: type: String
          children: [OriginalChildSchema]

        @OriginalParentModel = mongoose.model 'ParentOriginal', OriginalParentSchema
        @OriginalChildModel = mongoose.model 'ChildOriginal', OriginalChildSchema



        MigrationChildSchema = mongoose.Schema
          text: type: String

        MigrationChildSchema.plugin encrypt.migrations,  # add migrations plugin
                    encryptionKey: encryptionKey
                    signingKey: signingKey

        MigrationParentSchema = mongoose.Schema
          text: type: String
          children: [MigrationChildSchema]

        MigrationParentSchema.plugin encrypt.migrations,  # add migrations plugin
          encryptionKey: encryptionKey
          signingKey: signingKey

        @MigrationParentModel = mongoose.model 'ParentMigrate', MigrationParentSchema, 'parentoriginals'
        @MigrationChildModel = mongoose.model 'ChildMigrate', MigrationChildSchema


        # this buffer comes from a doc saved with the version of mongoose-encrypt without authentication
        bufferEncryptedWithOldVersion = new Buffer JSON.parse "[21,214,250,191,178,31,137,124,48,21,38,43,100,150,146,97,102,96,173,251,244,146,145,126,14,193,188,116,132,96,90,135,177,89,255,121,6,98,213,226,92,3,128,66,93,124,46,235,52,60,144,129,245,114,246,75,233,173,60,45,63,1,117,87]"
        bufferEncryptedWithOldVersion2 = new Buffer JSON.parse "[227,144,73,209,193,222,74,228,115,162,19,213,103,68,229,61,81,100,152,178,4,134,249,159,245,132,29,186,163,91,211,169,77,162,140,113,105,136,167,174,105,24,50,219,80,150,226,182,99,45,236,85,133,163,19,76,234,83,158,231,68,205,158,248]"

        docWithChildrenFromOldVersion =
          children: [
            { _ct: bufferEncryptedWithOldVersion, _id: new mongoose.Types.ObjectId() }
            { _ct: bufferEncryptedWithOldVersion2, _id: new mongoose.Types.ObjectId() }
           ]

        @OriginalParentModel.collection.insert [docWithChildrenFromOldVersion], (err, raw) =>
          assert.equal err, null
          docs = raw.ops || raw
          @docId = docs[0]._id
          done()

      after (done) ->
        @OriginalParentModel.remove {}, (err) ->
          assert.equal err, null
          done()

      # This test is intentionally skipped to prevent misleading console messages
      it.skip 'migration definitely needed', (done) ->
        # This test is ok to skip because it doesn't test functionality, it just confirms that the migration is needed
        # And it (correctly) causes errors to be logged to the console, which could be misleading
        @OriginalParentModel.findById @docId, (err, doc) ->
          assert.equal err, null, 'When error in subdoc pre init hook, swallowed by mongoose'
          assert.isArray doc.children
          assert.lengthOf doc.children, 0, 'Children have errors in pre-init and so are no hydrated'

      it 'should transform existing documents in collection such that they work with plugin version A', (done) ->
        @MigrationParentModel.migrateSubDocsToA 'children', (err) =>
          assert.equal err, null

          @OriginalParentModel.findById @docId, (err, migratedDoc) =>
            assert.equal err, null
            assert.isArray migratedDoc.children
            assert.lengthOf migratedDoc.children, 2
            assert.propertyVal migratedDoc.children[0], 'text', 'Child unencrypted text'
            assert.propertyVal migratedDoc.children[1], 'text', 'Child2 unencrypted text'
            done()

  describe 'signAll static model method', ->

    schemaObject =
      text: type: String
      bool: type: Boolean
      num: type: Number

    UnsignedSchema = mongoose.Schema schemaObject

    UnsignedSchema.plugin encrypt.migrations,
      encryptionKey: encryptionKey
      signingKey: signingKey

    UnsignedModel = mongoose.model 'Sign', UnsignedSchema


    before (done) ->
      plainDoc =
        text: 'Plain'
        bool: true

      plainDoc2 =
        bool: false
        num: 33

      UnsignedModel.collection.insert [plainDoc, plainDoc2], (err, raw) =>
        assert.equal err, null
        docs = raw.ops || raw
        @docId = docs[0]._id
        @doc2Id = docs[1]._id
        done()

    after (done) ->
      UnsignedModel.remove {}, (err) ->
        assert.equal err, null
        done()

    it 'should transform documents in an unsigned collection such that they are signed and work with plugin version A', (done) ->
      UnsignedModel.signAll (err) =>
        assert.equal err, null

        # add back in middleware
        UnsignedSchema.plugin encrypt,
          encryptionKey: encryptionKey
          signingKey: signingKey,
          _suppressDuplicatePluginError: true # to allow for this test

        UnsignedModel.findById @docId, (err, signedDoc) =>
          assert.equal err, null, 'There should be no authentication error after signing'
          assert.propertyVal signedDoc, 'text', 'Plain'
          assert.propertyVal signedDoc, 'bool', true
          done()

  describe 'installing on schema alongside standard encrypt plugin', ->
      it 'should throw an error if installed after standard encrypt plugin', ->
        EncryptedSchema = mongoose.Schema
          text: type: String
        EncryptedSchema.plugin encrypt, secret: secret
        assert.throw -> EncryptedSchema.plugin encrypt.migrations, secret: secret
      it 'should cause encrypt plugin to throw an error if installed first', ->
        EncryptedSchema = mongoose.Schema
          text: type: String
        EncryptedSchema.plugin encrypt.migrations, secret: secret
        assert.throw -> EncryptedSchema.plugin encrypt, secret: secret
