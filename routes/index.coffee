passport = require "passport"
config   = require "config"

User     = require("../model/user")
Mailer   = require("../lib/mailer")
Image    = require("../lib/image")

image  = new Image(config.Upload)
mailer = new Mailer()

handleResult = (result, redirect) ->
  if redirect
    res.writeHead 302,
      Location: redirect.replace(/%s/, encodeURIComponent(JSON.stringify(result)))
    res.end()
  else
    res.writeHead 200,
      "Content-Type": (if req.headers.accept.indexOf("application/json") isnt -1 then "application/json" else "text/plain")
    res.end JSON.stringify(result)

setNoCacheHeaders = ->
  res.setHeader "Pragma", "no-cache"
  res.setHeader "Cache-Control", "no-store, no-cache, must-revalidate"
  res.setHeader "Content-Disposition", "inline; filename=\"files.json\""

module.exports = (app) ->
  # Helpers
  isAuthenticated = (req, res, next) ->
    if req.isAuthenticated()
      next()
    else
      res.redirect "/login"

  userExist = (req, res, next) ->
    User.count
      username: req.body.username
    , (err, count) ->
      if count is 0
        next()
      else
        res.redirect "/singup"

  # Routes
  app.get "/", (req, res) ->
    if req.isAuthenticated()
      res.render "home",
        user: req.user

    else
      res.render "home",
        user: null

  app.get "/login", (req, res) ->
    res.render "user/login"

  app.post "/login", passport.authenticate("local",
    successRedirect: "/"
    failureRedirect: "/login"
  )
  app.get "/signup", (req, res) ->
    res.render "user/signup"

  app.post "/signup", userExist, (req, res, next) ->
    User.signup req.body.email, req.body.password, (err, user) ->
      return next(err) if err
      mailer.sendSignupConfirmation user.email, (err, response) ->
        return next(err) if err
        req.login user, (err) ->
          return next(err)  if err
          res.redirect "/profile"

  app.get "/forgot/password", (req, res, next) ->
    res.render "user/forgotPassword"

  app.post "/forgot/password", (req, res, next) ->
    User.findOne email: req.body.email, (err, user) ->
      return next(err) if err
      if !user
        return res.render "user/forgotPassword", email: req.body.email, warningMessage: 'Email was not found'
      user.requestResetPassword (err, user) ->
        return next(err) if err
        url = 'http://' + req.host + '/reset/password?key=' + user.regeneratePasswordKey
        mailer.sendForgotPassword user.email, url, (err, response) ->
          return next(err) if err
          res.render "user/forgotPassword", successMessage: 'We\'ve sent to you a email. Check your mail box.'

  app.get "/reset/password", (req, res, next) ->
    User.findOne regeneratePasswordKey: req.query.key, (err, user) ->
      return next(err) if err
      if !user
        # @todo: detect here if an IP is searching for available key otherwise block this IP for few days
        return res.redirect "/"
      res.render "user/resetPassword", regeneratePasswordKey: user.regeneratePasswordKey

  app.post "/reset/password", (req, res, next) ->
    User.findOne regeneratePasswordKey: req.body.regeneratePasswordKey, (err, user) ->
      return next(err) if err
      if !user
        # @todo: detect here if an IP is searching for available key otherwise block this IP for few days
        return res.redirect "/"
      if req.body.password
        user.updatePassword req.body.password, (err) ->
          return next(err) if err
          url = 'http://' + req.host + '/forgot/password'
          mailer.sendPasswordReseted user.email, url, (err, response) ->
            return next(err) if err
            res.render "user/resetPassword", successMessage: 'Your password has been updated. Please login again.'

  app.get "/auth/facebook", passport.authenticate("facebook",
    scope: "email"
  )
  app.get "/auth/facebook/callback", passport.authenticate("facebook",
    failureRedirect: "/login"
  ), (req, res) ->
    res.render "user/profile",
      user: req.user

  app.get "/profile", isAuthenticated, (req, res) ->
    res.render "user/profile",
      user: req.user

  app.post "/profile", isAuthenticated, (req, res) ->
    res.redirect "user/profile"

  app.post "/profile-picture", isAuthenticated, (req, res, next) ->
    image.saveUserPicture req.user, req.files.picture, (err, pictureInfo) ->
      return next(err) if err
      baseUrl = ((if config.Upload.sslEnabled then "https:" else "http:")) + "//" + req.host + '/'
      res.json files: [
        name: pictureInfo.name
        size: pictureInfo.size
        thumbnailUrl: baseUrl + pictureInfo.thumbnailUrl
        type: pictureInfo.type
        url:  baseUrl + pictureInfo.url
      ]

  app.delete "/profile-picture", isAuthenticated, (req, res, next) ->
    image.destroyUserPicture req.user

  app.get "/logout", (req, res) ->
    req.logout()
    res.redirect "/login"