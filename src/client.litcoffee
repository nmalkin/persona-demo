Persona Demo: Client
====================
This file provides the entirety of the client-side interaction of our demo app.
Specifically, it takes care of:

- Logging in
- Logging out
- Retrieving and displaying the "content" of our application

The authentication functions are, of course, performed using Persona.

## Note
If you take a look at `index.html`
([located](https://github.com/nmalkin/persona-demo/blob/master/app/public/index.html)
in `app/public`), you'll see that
it's extremely bare-bones. The client-side JavaScript takes care of the heavy
lifting. *All* the lifting, actually. Note that this doesn't have to be the case.

For example (as you'll see), the client checks with the server about its
authentication status and asks for the private content if appropriate. You
could, instead, have the server perform these checks when the user initially
requests the index page and then render a template.
Either way is fine.

## Prerequisites
Look at `index.html` again. Notice that a couple of things are already in place
for us. First, the "sign in" and "sign out" buttons are there (though hidden
for now), as is a `<div>` where we promise to put the content.

More interestingly, a couple of JavaScript files are included.
First, there's [jQuery](http://jquery.com). It's there to simplify
[DOM](https://developer.mozilla.org/en-US/docs/DOM) manipulation and AJAX calls.

The other file that is loaded is `https://login.persona.org/include.js`.
This is the _JavaScript shim_ for the Persona API. What is it and why do we
need it?

Persona implements the _BrowserID protocol_, which is based on the idea of your
browser managing the entirety of the authentication process for you. However,
not all browsers may implement this protocol (at present, none do, though this
functionality is in development for Firefox). To allow anyone to sign in, even
if their browser doesn't support BrowserID, Mozilla provides this shim, which
implements all the necessary functionality.


## The Watch API
Okay, let's get started!

The centerpiece of the client-side Persona protocol is the _Watch API_.
You use it to define the behavior of your page when one of two main interactions
takes place: a login event or logout event.

You'll need to create an object with fields named `onlogin` and `onlogout`
and assign a callback to each. These will be called when the respective event
occurs.

    init = ->
        watchOptions =
            onlogin: loginFunction
            onlogout: logoutFunction
            loggedInUser: currentUser

The other field in the options object is `loggedInUser`. This is the email
address of the user you think is logged in when your page loads
(assuming you think someone is logged in; it should be `null` otherwise).
It's there to make sure you and Persona agree on the state of your application.
If there's a disagreement (for example, you think someone's logged in, but
Persona sees the user as logged out), the appropriate callback will be triggered
when the page is loaded, to get you on the same page.

Once you have the options, you need to activate them by calling the
`navigator.id.watch` function (provided, as described above, either by your
browser or by the shim).

        navigator.id.watch watchOptions


## Logging in
What happens when a user tries to log in? As suggested above, Persona will call
the login function that you give to the Watch API. As its argument, this
function will receive an _assertion_, a token that encodes the user's claim
about their identity ("Hi, I'm user@example.com").

You can't just take their word for it, though; you'll need to verify this
assertion. This has to be done by the server. So, on the client side,
we'll just take the assertion and pass it on to our server to do the real work.
Once we hear back from the server, we'll know whether the login was successful.

    loginFunction = (assertion) ->
        $.post '/verify', assertion: assertion, (response) ->
            if response is 'yes'
                showPrivatePage()
            else if response is 'no'
                alert 'Uh oh. Sign-in failed!'


### Showing the private page
If the user signed in successfully, they will be rewarded with a "private" page,
displayed only to logged-in users. On the client side, we just load
this page. On the server, we'll have to additionally check that the user
requesting this page is actually logged in.

    showPrivatePage = ->
        $('#login').hide()
        $('#logout').show()
        $('#content').load '/private'


## Logging out
On logout, our other callback will be called. This is even easier, as there
are only two things that need to happen.

1. We need to update the page for a logged-out user.
2. We need to tell the server that the current user is logging out.

    logoutFunction = ->
        showPublicPage()
        $.post '/logout'

    showPublicPage = ->
        $('#login').show()
        $('#logout').hide()
        $('#content').html ''


## Initial state
You may remember, from above, the `loggedInUser` field that we gave to
`navigator.id.watch`. It told Persona who we think is logged in when the page loads.
If you are generating your page on the server-side, with a template, you can
pre-fill this field with the email address of the current user.
We aren't, so we'll instead query the server and ask it about the state of
the current user. (If no one is logged in, we'll have the server return `idk`.)
Once we've done this, we're all set to initialize Persona.

    currentUser = null
    $.get '/whoami', (email) ->
        if email is 'idk'
            showPublicPage()
        else
            currentUser = email
            showPrivatePage()
        init()

## Triggering login and logout events
We've covered almost everything on the client side, except for one thing!
We talked about getting login and logout events, but how do we tell when the user
wants to sign in or sign out? We already have the necessary buttons, we just
need to associate the right behaviors with them.

When users click on the "Sign in" and "Sign out" buttons, we want 
`navigator.id.watch` to trigger the login and logout functions we provided.
To do this, we make use of two more small and straightforward pieces of the
`navigator.id` API.

    $('#login').click ->
        navigator.id.request()

    $('#logout').click ->
        navigator.id.logout()


That's it! This is everything you need for Persona to work on the client-side.
Be sure to check out [what happens on the server](server.html), too.
