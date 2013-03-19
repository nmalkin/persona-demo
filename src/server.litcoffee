Persona Demo: Server
====================
This file provides an implementation of the server for our demo app.
The server is responsible primarily for providing the API with which the client
interacts.

The specific functionality provided by the server includes:

- Serving the static files that constitute the client
- Verifying the assertions supplied by Persona to the client
- Managing user sessions
- Serving restricted content

Let's tackle these in order.


## The framework
For this demo, we'll use the [Express framework](http://expressjs.com/) for
[node.js](http://nodejs.org/) to manage the routes for the app's
API.

    express = require 'express'
    app = express()

We'll also use some of the middleware Express provides, which will help us:

- log requests (useful for debugging)
- serve static files
- parse the body of requests
- manage sessions

    app.use express.logger()
    app.use express.static __dirname + '/public'
    app.use express.bodyParser()
    app.use express.cookieParser()
    app.use express.cookieSession secret: process.env.SECRET || 'shhhhhhhhhhh!'


## Verifying assertions
In our demo, the biggest job of the server is to verify the assertions generated
by Persona and given to the client. Since users can tamper with anything that
happens on the client side, verification must be done by the server.

The [specs for the BrowserID protocol][] describe how assertions should be verified.
However, the cryptography can be tricky, and doing it yourself may get complicated.
Instead, you will almost definitely want to use the [Remote Verification API][],
provided by Mozilla, to verify your assertions. That's what we'll do in this
demo.

[specs for the BrowserID protocol]: https://github.com/mozilla/id-specs/blob/prod/browserid/index.md
[Remote Verification API]: https://developer.mozilla.org/en-US/docs/Persona/Remote_Verification_API

To use the Remote Verification API, you make a POST request to Mozilla's servers
with two pieces of information.

1. The assertion
2. The audience

We already saw the assertion in the client: it's a token containing a
cryptographically signed claim about the identity of your user.

The _audience_ is the protocol, domain name, and port of your site.
For example, if your login page is at `example.com/login`, and you're serving
it over HTTPS, and running on port 443, your audience would be
`https://example.com:443`.

__Important__: the audience must match the server for which the assertion is
generated. So, if you host your login page at `example.com` but you declare
your audience as `http://example.org`, there's going to be a mismatch, and
verification will fail.
(The same problem will occur if you run the demo on `localhost` instead of
`127.0.0.1`.)

#### Remote Verification API in action
Here, we formulate the request that we'll make to the Remote Verification API
by first putting together the body (consisting of the assertion and audience),
and then the headers. The headers contain the destination of the request
(`verifier.login.persona.org/verify`), specify that this is a POST request,
and include the `Content-Length` of the body (this is a required field!).

Then we actually make the request. `makeRequest` isn't a built-in function; we
will implement it later.

The response from the server will contain a status — `okay` if verification
succeeded — and an email address, if it did.

    app.post '/verify', (req, res) ->
        assertion = req.body.assertion

        requestBody = JSON.stringify
            assertion: assertion
            audience: process.env.AUDIENCE || 'http://127.0.0.1:' + PORT

        requestHeaders =
            host: 'verifier.login.persona.org'
            path: '/verify'
            method: 'POST'
            headers:
                'Content-Length': requestBody.length
                'Content-Type': 'application/json'

        makeRequest requestHeaders, requestBody, (responseBody) ->
            response = JSON.parse responseBody
            if response.status is 'okay'
                req.session.email = response.email
                res.send 'yes'
            else
                req.session = null
                res.send 'no'
                console.log response # so you know what went wrong

Notice that after receiving the response from the verifier, we update the user's
session. This will be important for the following steps.


## Managing user sessions
In addition to verifying assertions, the client makes two kinds of calls to the
server to manage users' identities.

1. When it wants to find out if a user is currently logged in
2. When it's telling the server that a user has logged out

Above, we stored information about the user's authentication status in their
session. Now, we'll use that information to perform these two tasks.

    app.get '/whoami', (req, res) ->
        if 'email' of req.session
            res.send req.session.email
        else
            res.send 'idk'
            
    app.post '/logout', (req, res) ->
        req.session = null
        res.send 'done'


## Serving private content
If your app is using authentication, there's probably some part of it that only
logged-in users should see. To demo this functionality, we provide a page that
displays content only to authorized users.

    app.get '/private', (req, res) ->
        if 'email' of req.session
            res.send "Hey there! You're logged in as #{req.session.email}."
        else
            res.send "Whoa, you're not logged in. Nothing to see here, move along!"


## Missing pieces
If you've made it this far, congratulations! You should now have a working
understanding of the Persona API. The remainder of this file fills in a few
missing pieces that will make our app work.

Above, when we made a call to the verifier service, we used `makeRequest`,
which is just a convenience function that makes the API for sending HTTPS
requests a little bit cleaner. We define it now.

    https = require 'https'

    makeRequest = (headers, body, callback) ->
        vreq = https.request headers, handleResponse callback
        vreq.write body

Handling the response to the server involves listening for chunks of data and
accumulating them as they come in. The `end` event signals to us that we're done.

    handleResponse = (callback) ->
        (vres) ->
            responseBody = ''
            vres.on 'data', (chunk) ->
                responseBody += chunk
            vres.on 'end', ->
                callback responseBody

One last step to set our app into motion:

    PORT = 8080 # default port
    app.listen process.env.PORT || PORT

And now we're done! You now know what it takes to get Persona to work on your
server. (And if you haven't already, be sure to see [what happens on the client
side](client.html) as well.)

That wasn't so bad, was it? Now it's your turn. Go!

