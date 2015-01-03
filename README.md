RxP
===

Reactive promises

I like promises and the simplicity of chaining async operations
together. Especiall I like that `.then` can take a normal value or a
deferred value - who cares whether it's deferred or now?

But then when a promise is resolved it is over. Reactive programming
(RP), such as [RxJS](https://github.com/Reactive-Extensions/RxJS), or
functional reactive programming (FRP), such as
[Bacon.js](https://baconjs.github.io/), are very similar to promises,
only, an event stream doesn't end until you want it to. But then both
RxJS and Bacon.js have API that lack the elegance of promises.

The case for `.then` (and against `.flatMap`)
---------------------------------------------

Example taken from Bacon.js tutorial (and turned into coffeescript):

    username = textFieldValue($("#username input"))
    availabilityRequest = username.changes().map((user) -> url:"/usernameavailable/" + user)
    toResultStream = (request) -> Bacon.fromPromise($.ajax(request))
    avaivailabilityResponse = availabilityRequest.flatMap(toResultStream)

So when the username changes, we transform the username into a
url-object, which in turn happens to be the perfect input to a jQuery
request. We're interested in responses to them and
suddenly... `.flatMap`

Why `flatMap`? (yes I know, collect the result of a nested stream
and...  *yawn yawn*). But why do I care?

This is why I like promises:

  * `.then` is very similar to `.flatMap` in that it also waits for
    the wrapped promise (or stream) and returns that result.
  * As a lazy promise developer I don't really care whether the value
    is available now or in the future, I just go
    `.then().then().then()`.
  * As an RP developer I need to always know whether I'm dealing with
a "normal" non-deferred value (`.map`) or a wrapped stream
(`.flatMap`). But then, `.flatMap` tends to work for also non-deferred
values, so I could just always go `.flatMap().flatMap().flatMap()` -
why do we have `.map()` again?

If only promises could deal with multiple values (and not just stop after one).

