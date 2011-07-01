if (process.argv[2] == 'production') {
  var TARGET = 'https://app584241.heroku.cloudant.com';
  var USERNAME = 'meneveguentenerestakewhi';
  var PASSWORD = '4NmBXtNCpylinPauG5SEmSrV';
  var PREFIX = '/timeline/';
  var PORT = 5984;
  var ERROR = function(e) {
    sys.log(e.stack);
    Hoptoad.key = 'fc48013989cadeb32a1a262a3dab7cb1';
    Hoptoad.notify(e);
  };
} else {
  var TARGET = 'http://localhost:5984';
  var USERNAME = '';
  var PASSWORD = '';
  var PREFIX = '/timeline/';
  var PORT = 8001;
  var ERROR = function(e) {
    sys.log(e.stack);
  };
}

var sys = require('sys');
var http = require('http');
var https = require('https');
var url = require('url');
var querystring = require('querystring');
var _ = require('../brunch/src/vendor/underscore-1.1.6.js');
var Hoptoad = require('./hoptoad-notifier').Hoptoad;

// Unhandled Node exceptions
process.on('uncaughtException', function(e) {
  ERROR(e);
});

// Server
function handleRequest(request, response) {
  var u = url.parse(request.url);
  // Only serve URLs that start with PREFIX
  if (u.pathname.substring(0, PREFIX.length) != PREFIX) {
    return error(response, 'not found', 'Nothing found here.', 404);
  }
  u = TARGET + u.pathname.substring(PREFIX.length-1) + (u.search || '');
  forwardRequest(request, response, u);
}
http.createServer(handleRequest).listen(PORT);
sys.puts('Proxy ready on port ' + PORT + '.');

// Authenticates using Facebook, then proxies to CouchDB
function forwardRequest(inRequest, inResponse, uri) {
  sys.log(inRequest.method + ' ' + uri);
  uri = url.parse(uri, true);
  
  // Construct the incoming request body
  var inData = ''
  inRequest.on('data', function(chunk) {
    inData += chunk;
    outRequest.write(chunk)
  });
  
  inRequest.on('end', function() {
    
    // Facebook authentication
    
    // Parse query string or request body
    if (inRequest.method == 'GET') {
      var params = uri.query;
    } else {
      var params = querystring.parse(inData);
    }

    var authStarted = false;
    var authAttempt = setInterval(function() {
      
      if (!authStarted && !fbAuth.authenticated[params.token]) {
        // User has not been authenticated, so authenticate
        authStarted = true;
        fbAuth.authenticate(params.token);
      
      } else if (fbAuth.authenticated[params.token] && fbAuth.authenticated[params.token].fbId && fbAuth.authenticated[params.token].friends) {
        // User has been authenticated, so time to proxy
        clearInterval(authAttempt);
        
        var headers = inRequest.headers;  
        headers['host'] = uri.hostname + ':' + (uri.port||80);
        headers['x-forwarded-for'] = inRequest.connection.remoteAddress;
        headers['referer'] = 'http://' + uri.hostname + ':' + (uri.port||80) + '/';
        
        // Append Facebook data onto the querystring or request body before proxying the request
        
        // Proxy request
        var outRequest = http.request({
          host: uri.hostname,
          port: uri.port || 80,
          path: PREFIX + uri.pathname + (uri.search || ''),
          method: inRequest.method,
          headers: headers
        });

        outRequest.on('error', function(e) {
          unknownError(inResponse, e);
        });
        
        // Proxy response is coming back from CouchDB
        outRequest.on('response', function(outResponse) {
          // nginx does not support chunked transfers for proxied requests
          delete outResponse.headers['transfer-encoding'];
          
          if (outResponse.statusCode == 503) {
            return error(inResponse, 'database unavailable', 'Database server not available.', 503);
          }

          // Construct the body of the response from CouchDB
          outResponse.on('data', function(chunk) {
            inResponse.write(chunk);
          });
          
          // CouchDB is done responding, so send that response back
          outResponse.on('end', function() {
            inResponse.end();
          });

        });
        
        // All event handlers have been bound to the proxy request, so end it to CouchDB
        outRequest.end();
      
      } else if (authStarted && !fbAuth.authenticated[params.token]) {
        // Authentication failed
        clearInterval(authAttempt);
        return error(inResponse, 'unauthorized', 'Facebook authentication failed.', 401);
      }
      
      // else: just wait for Facebook Graph API calls to return
    }, 100);
  });
};

function error(response, error, reason, code) {
  sys.log('Error '+code+': '+error+' ('+reason+').');
  response.writeHead(code, { 'Content-Type': 'application/json' });
  response.write(JSON.stringify({ error: error, reason: reason }));
  response.end();
}

function unknownError(response, e) {
  sys.log(e.stack);
  error(response, 'unknown error', 'An unknown error occured, was logged and will be looked into. Sorry about that!', 500);
}

// Changes a Facebook token into a Facebook ID, and verifies friend lists, to prevent any funny business
var FbAuth = function() {
  var self = this;
  this.authenticated = {};
  
  this.authenticate = function(token) {
    self.authenticated[token] = {fbId: null, friends: null, timestamp: new Date()};
    
    // FB UID
    var dataMe = ''
    var reqMe = https.request({host: 'graph.facebook.com', path: '/me?'+querystring.stringify({access_token: token})}, function(res) {
      res.on('data', function(data) {
        dataMe += data.toString('utf8');
      });
      res.on('end', function() {
        dataMe = JSON.parse(dataMe);
        if (self.authenticated[token] && res.statusCode == 200) {
          // Succesful API calls
          self.authenticated[token].fbId = dataMe.id;
          console.log('Facebook user '+dataMe.id);
        } else {
          // API error
          delete self.authenticated[token];
          console.error(dataMe);
        }
      });
    });
    
    reqMe.on('error', function(e) {
      delete self.authenticated[token];
    });
    
    reqMe.end();
    
    // FB friends
    var dataFriends = ''
    var reqFriends = https.request({host: 'graph.facebook.com', path: '/me/friends?'+querystring.stringify({access_token: token})}, function(res) {      
      res.on('data', function(data) {
        dataFriends += data.toString('utf8');
      });
      res.on('end', function() {
        dataFriends = JSON.parse(dataFriends);
        if (self.authenticated[token] && res.statusCode === 200) {
          // Succesful API call
          var fbIds = [];
          for (var i = 0; i < dataFriends.data.length; i++) {
            fbIds.push(dataFriends.data[i].id);
          }
          self.authenticated[token].friends = fbIds;
          console.log('Facebook friend count '+fbIds.length);
        } else {
          // API error
          delete self.authenticated[token];
          console.error(dataFriends);
        }
        expireCache();
      });
    });
    
    reqFriends.on('error', function(e) {
      delete self.authenticated[token];
    });
    
    reqFriends.end();
  };
  
  function expireCache() {
    // Expire old authentication objects from the cache
    // Cached authenticated objects should not be older than an hour
    var now = new Date();
    for (var i = 0; i < self.authenticated.length; i++) {
      if (self.authenticated[i].timestamp - now < 3600000) {
        self.authenticated.splice(0, i);
        break;
      }
    }
    
    // Cache should not contain more than 50,000 keys (roughly 500MB of memory)
    if (self.authenticated.length > 50000) {
      self.authenticated.splice(0, 1);
    }
  }
};
var fbAuth = new FbAuth();