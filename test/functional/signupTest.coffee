request      = require 'supertest'
assert       = require 'assert'
should       = require 'should'
async        = require 'async'
mongoose     = require 'mongoose'
$            = require 'jquery'
App          = require '../../app'

fixtures     = require 'pow-mongoose-fixtures'
fixturesData = require '../../fixtures/test.coffee'

User = require '../../model/user'

describe '/signup', ->
  fakeUser = {}
  requestTest = {}

  describe '** Logged in **', ->
    before (done) ->
      async.series [(callback) ->
        fixtures.load fixturesData.testUser, mongoose.connection, callback
      , (callback) ->
        User.findById fixturesData.testUser.User.fakeUser._id, (err, user) ->
          fakeUser = user
          requestTest = request(new App(fakeUser))
          callback()
      ], done

    describe 'GET', ->
      it 'should redirect to /profile', (done) ->
        requestTest.get('/signup').expect(302).end (err, res) ->
          should.not.exist err
          res.header.location.should.equal('/profile')
          done()

  describe '** Logged out **', ->
    before (done) ->
      fixtures.load fixturesData.testUser, mongoose.connection, done

    describe 'GET', ->
      it 'should return 200', (done) ->
        request(new App()).get('/signup').expect(200).end (err, res) ->
          should.not.exist err
          done()

    describe 'POST', ->
      describe 'User not already registered', ->
        it 'should redirect to /signupConfirmation when signup is successfull', (done) ->
          request(new App()).post('/signup')
            .set('Accept-Language', 'fr-FR,fr;q=0.8,en-US;q=0.6,en;q=0.4')
            .send(email: 'new@email.com', password: 'password')
            .expect(302).end (err, res) ->
              should.not.exist(err)
              res.header['location'].should.include('/signupConfirmation')
              done()
        it 'should render /signup with error if email is missing', (done) ->
          request(new App()).post('/signup')
            .set('Accept-Language', 'fr-FR,fr;q=0.8,en-US;q=0.6,en;q=0.4')
            .send(password: 'password')
            .expect(200).end (err, res) ->
              should.not.exist(err)
              $body = $(res.text);
              $body.find('.alert.alert-danger').text().should.equal('×Le formulaire comporte des erreurs')
              done()
      describe 'User already registered', ->
        userData = fixturesData.testUser.User.fakeUser;
        it 'should redirect to /login even if password is correct', (done) ->
          request(new App()).post('/signup')
            .set('Accept-Language', 'fr-FR,fr;q=0.8,en-US;q=0.6,en;q=0.4')
            .send(email: userData.email, password: 'password')
            .expect(200).end (err, res) ->
              should.not.exist(err)
              $body = $(res.text);
              $body.find('.alert.alert-danger').text().should.equal('×Email already exists.')
              done()