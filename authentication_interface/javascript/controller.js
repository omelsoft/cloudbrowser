(function() {
  var CBAuthentication, CloudBrowserDb, CloudBrowserDb_server, Crypto, Express, HashPassword, Https, Mongo, MongoStore, Xml2JS, authentication_string, baseURL, defaults, getJSON, mongoStore, mountPoint, nodemailer, rootURL, sendActivationEmail,
    __hasProp = Object.prototype.hasOwnProperty;

  Mongo = require("mongodb");

  Express = require("express");

  MongoStore = require("connect-mongo")(Express);

  Https = require("https");

  Xml2JS = require("xml2js");

  Crypto = require("crypto");

  nodemailer = require("nodemailer");

  CBAuthentication = angular.module("CBAuthentication", []);

  CloudBrowserDb_server = new Mongo.Server(config.domain, 27017, {
    auto_reconnect: true
  });

  CloudBrowserDb = new Mongo.Db("cloudbrowser", CloudBrowserDb_server);

  mongoStore = new MongoStore({
    db: "cloudbrowser_sessions"
  });

  mountPoint = bserver.mountPoint.split("/")[1];

  rootURL = "http://" + config.domain + ":" + config.port;

  baseURL = rootURL + "/" + mountPoint;

  defaults = {
    iterations: 10000,
    randomPasswordStartLen: 6,
    saltLength: 64
  };

  HashPassword = function(config, callback) {
    var k, v;
    if (config == null) config = {};
    for (k in defaults) {
      if (!__hasProp.call(defaults, k)) continue;
      v = defaults[k];
      config[k] = config.hasOwnProperty(k) ? config[k] : v;
    }
    if (!(config.password != null)) {
      return Crypto.randomBytes(config.randomPasswordStartLen, function(err, buf) {
        if (err) {
          return console.log(err);
        } else {
          config.password = buf.toString('base64');
          return HashPassword(config, callback);
        }
      });
    } else if (!(config.salt != null)) {
      return Crypto.randomBytes(config.saltLength, function(err, buf) {
        if (err) {
          return console.log(err);
        } else {
          config.salt = new Buffer(buf);
          return HashPassword(config, callback);
        }
      });
    } else {
      return Crypto.pbkdf2(config.password, config.salt, config.iterations, config.saltLength, function(err, key) {
        if (err) {
          return console.log(err);
        } else {
          config.key = key;
          return callback(config);
        }
      });
    }
  };

  sendActivationEmail = function(toEmailID, callback) {
    return Crypto.randomBytes(32, function(err, buf) {
      var confirmationMsg, mailOptions, smtpTransport;
      if (err) {
        return callback(err, null);
      } else {
        buf = buf.toString('hex');
        confirmationMsg = "Please click on the link below to verify your email address.<br>" + ("<p><a href='" + baseURL + "/activate/" + buf + "'>Activate your account</a></p>") + ("<p>If you have received this message in error and did not sign up for a cloudbrowser account, click <a href='" + baseURL + "/deactivate/" + buf + "'>not my account</a></p>");
        smtpTransport = nodemailer.createTransport("SMTP", {
          service: "Gmail",
          auth: {
            user: "ashimaathri@gmail.com",
            pass: "Jgilson*2716"
          }
        });
        mailOptions = {
          from: "ashimaathri@gmail.com",
          to: toEmailID,
          subject: "Activate your CloudBrowser Account",
          html: confirmationMsg
        };
        return smtpTransport.sendMail(mailOptions, function(error, response) {
          if (error) {
            callback(error, null);
          } else {
            callback(null, buf);
          }
          return smtpTransport.close();
        });
      }
    });
  };

  CloudBrowserDb.open(function(err, Db) {
    if (!err) {
      return console.log("The authentication interface is connected to the database");
    } else {
      return console.log(err);
    }
  });

  authentication_string = "?openid.ns=http://specs.openid.net/auth/2.0" + "&openid.ns.pape=http:\/\/specs.openid.net/extensions/pape/1.0" + "&openid.ns.max_auth_age=300" + "&openid.claimed_id=http:\/\/specs.openid.net/auth/2.0/identifier_select" + "&openid.identity=http:\/\/specs.openid.net/auth/2.0/identifier_select" + "&openid.return_to=" + baseURL + "/checkauth?redirectto=" + (bserver.redirectURL != null ? bserver.redirectURL : "") + "&openid.realm=" + rootURL + "&openid.mode=checkid_setup" + "&openid.ui.ns=http:\/\/specs.openid.net/extensions/ui/1.0" + "&openid.ui.mode=popup" + "&openid.ui.icon=true" + "&openid.ns.ax=http:\/\/openid.net/srv/ax/1.0" + "&openid.ax.mode=fetch_request" + "&openid.ax.type.email=http:\/\/axschema.org/contact/email" + "&openid.ax.type.language=http:\/\/axschema.org/pref/language" + "&openid.ax.required=email,language";

  getJSON = function(options, callback) {
    var request;
    request = Https.get(options, function(res) {
      var output;
      output = '';
      res.setEncoding('utf8');
      res.on('data', function(chunk) {
        return output += chunk;
      });
      return res.on('end', function() {
        return callback(res.statusCode, output);
      });
    });
    request.on('error', function(err) {
      return callback(-1, err);
    });
    return request.end;
  };

  CBAuthentication.controller("LoginCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.login_error = null;
    $scope.isDisabled = false;
    $scope.remember = true;
    $scope.login = function() {
      if (!($scope.email != null) || !($scope.password != null)) {
        return $scope.login_error = "Please provide both the Email ID and the password";
      } else {
        $scope.isDisabled = true;
        CloudBrowserDb.collection("users", function(err, collection) {
          if (!err) {
            return collection.findOne({
              email: $scope.email
            }, function(err, user) {
              if (user && user.status !== 'unverified') {
                return HashPassword({
                  password: $scope.password,
                  salt: new Buffer(user.salt, 'hex')
                }, function(result) {
                  var sessionID;
                  if (result.key.toString('hex') === user.key) {
                    sessionID = decodeURIComponent(bserver.getSessions()[0]);
                    return mongoStore.get(sessionID, function(err, session) {
                      if (!err) {
                        session.user = $scope.email;
                        /*
                                                                    if $scope.remember
                                                                        session.cookie.maxAge = 24 * 60 * 60 * 1000
                                                                        #notify the client
                                                                        bserver.updateCookie(session.cookie.maxAge)
                                                                    else
                                                                        session.cookie.expires = false
                        */
                        return mongoStore.set(sessionID, session, function() {
                          if (typeof redirectURL !== "undefined" && redirectURL !== null) {
                            return bserver.redirect(baseURL + redirectURL);
                          } else {
                            return bserver.redirect(baseURL);
                          }
                        });
                      } else {
                        return console.log("Error in finding the session:" + sessionID + " Error:" + err);
                      }
                    });
                  } else {
                    return $scope.$apply(function() {
                      return $scope.login_error = "Invalid Credentials";
                    });
                  }
                });
              } else {
                return $scope.$apply(function() {
                  return $scope.login_error = "Invalid Credentials";
                });
              }
            });
          } else {
            return console.log(err);
          }
        });
        return $scope.isDisabled = false;
      }
    };
    $scope.googleLogin = function() {
      return getJSON("https://www.google.com/accounts/o8/id", function(statusCode, result) {
        if (statusCode === -1) {
          return $scope.$apply(function() {
            return $scope.login_error = "There was a failure in contacting the google discovery service";
          });
        } else {
          return Xml2JS.parseString(result, function(err, result) {
            var path, uri;
            uri = result["xrds:XRDS"].XRD[0].Service[0].URI[0];
            path = uri.substring(uri.indexOf('\.com') + 4);
            return bserver.redirect("https://www.google.com" + path + authentication_string);
          });
        }
      });
    };
    return $scope.$watch("email + password", function() {
      $scope.login_error = null;
      return $scope.isDisabled = false;
    });
  });

  CBAuthentication.controller("SignupCtrl", function($scope) {
    $scope.email = null;
    $scope.password = null;
    $scope.vpassword = null;
    $scope.email_error = null;
    $scope.signup_error = null;
    $scope.password_error = null;
    $scope.success_message = null;
    $scope.isDisabled = false;
    $scope.$watch("email", function(nval, oval) {
      $scope.email_error = null;
      $scope.signup_error = null;
      $scope.isDisabled = false;
      return CloudBrowserDb.collection("users", function(err, collection) {
        if (!err) {
          return collection.findOne({
            email: nval
          }, function(err, item) {
            if (item) {
              return $scope.$apply(function() {
                $scope.email_error = "Account with this Email ID already exists";
                return $scope.isDisabled = true;
              });
            }
          });
        } else {
          return console.log(err);
        }
      });
    });
    $scope.$watch("password+vpassword", function() {
      $scope.signup_error = "";
      $scope.password_error = "";
      return $scope.isDisabled = false;
    });
    $scope.signup = function() {
      $scope.isDisabled = true;
      if (!($scope.email != null) || !($scope.password != null)) {
        return $scope.signup_error = "Must provide both Email and Password!";
      } else if (!/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test($scope.email.toUpperCase())) {
        return $scope.email_error = "Not a valid Email ID!";
      } else if (!/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test($scope.password)) {
        return $scope.password_error = "Password must be have a length between 8 - 15 characters, must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character. Spaces are not allowed.";
      } else {
        return sendActivationEmail($scope.email, function(err, buf) {
          if (!err) {
            $scope.$apply(function() {
              return $scope.success_message = true;
            });
            return CloudBrowserDb.collection("users", function(err, collection) {
              if (!err) {
                return HashPassword({
                  password: $scope.password
                }, function(result) {
                  var user;
                  user = {
                    email: $scope.email,
                    key: result.key.toString('hex'),
                    salt: result.salt.toString('hex'),
                    status: 'unverified',
                    token: buf
                  };
                  collection.insert(user);
                  return $scope.$apply(function() {
                    $scope.email = "";
                    $scope.password = "";
                    return $scope.vpassword = "";
                  });
                });
              } else {
                $scope.$apply(function() {
                  return $scope.signup_error = "Our system encountered an error! Please try again later.";
                });
                return console.log(err);
              }
            });
          } else {
            return $scope.$apply(function() {
              $scope.success_message = false;
              $scope.signup_error = "There was an error sending the confirmation email : " + err;
              $scope.email = "";
              $scope.password = "";
              return $scope.vpassword = "";
            });
          }
        });
      }
    };
    return $scope.googleLogin = function() {
      return getJSON("https://www.google.com/accounts/o8/id", function(statusCode, result) {
        if (statusCode === -1) {
          return $scope.$apply(function() {
            return $scope.login_error = "There was a failure in contacting the google discovery service";
          });
        } else {
          return Xml2JS.parseString(result, function(err, result) {
            var path, uri;
            uri = result["xrds:XRDS"].XRD[0].Service[0].URI[0];
            path = uri.substring(uri.indexOf('\.com') + 4);
            return bserver.redirect("https://www.google.com" + path + authentication_string);
          });
        }
      });
    };
  });

}).call(this);
