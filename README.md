XQ - Reactive Promises
======================

[![Build Status](https://travis-ci.org/algesten/xq.svg)](https://travis-ci.org/algesten/xq) [![Gitter](https://d378bf3rn661mp.cloudfront.net/gitter.svg)](https://gitter.im/algesten/xq)

XQ is a hybrid between promises and reactive extensions. Its core is a
[Promises/A+](https://promisesaplus.com/) compliant promises
implementation that can also function as a stream.

Think of it as a promise chain that you can push multiple values
down. `.then == .map`

## Get it

### Installing with NPM

```bash`
npm install -S xq
...
X = require 'xq'
```

### Download Source

```bash
git clone https://github.com/algesten/xq.git
```

## Example

### XQ as a Promise

```coffeescript
X = require 'xq'
X(42).then (v) -> console.log v
#... 42
```

#### As a deferred

```coffeescript
def = X.defer()
def.promise.then (v) ->
    v * 2
.then (v) ->
    console.log v
def.resolve 21
#... 42
```

### XQ as an Event Stream

Looping over an array.

```coffeescript
X([1,2,3,4]).each(v) ->
  X(v * 2)
.then (v) ->
  console.log v
#... 2
#... 4
#... 6
#... 8
```

### Pushing values

```coffeescript
def = X.defer()
def.promise.map (v) ->
    v * 2
.then (v) ->
    console.log v
def.push 11
def.push 21
def.push 22
#... 22
#... 42
#... 44
```

## Deferred values and Event Streams

XQ deals with event streams. A stream can be thought of as a sequence
of values, sometimes followed by an end-of-stream.

`v1 - v2 - v3 - end`

In XQ everything starts out as a non-ended stream.

```coffeescript
def = X.defer()
def.promise.map((v) -> v*2).then (v) -> console.log v
def.push 2
def.push 4
def.push 8
```

`2 - 4 - 8 - `

Here we created an event stream and pushed `2`, `4` and `8` down the
stream. After running `def.promise` will hold the value `8`. The
following `.map` holds the value `16` (8*2) and the final `.then` also
holds `16`. The stream is not ended, so we could continue pushing more
values to it. Each step would be executed for each new value pushed.

### A resolved promise is an event + end

A promise is just a special stream that always is ended when the
promise is resolved/rejected. The following examples are exactly
equivalent.

`X(2)`

`def = X.defer(); def.resolve(2); def.promise`

`def = X.defer(); def.push(2); def.end(); def.promise`

## OI `.oi(f)`

OI is a helper for passing multiple values through a promise/event
chain. Read [about OI](oi.md).

## API

### Instantiation

* **X(v)** creates an instance resolved with value `v`. Equivalent to
  `def.push(v); def.end()`.
* **X.reject(v)** creates an instance that is rejected with value
  `v`. Equivalent to `def.pushError(v); def.end()`.
* **X.resolver(f)** `f` is synchronously called with `resolve, reject` which are functions
  used to resolve/reject the promise. `X.resolve((resolve, reject) -> ... resolve(42))`
* **X.binder(f)** `f` is synchronously called with `sink`, `end` The
  sink function is used to sink events/errors. The signature of the
  sink function is `(v, isErr) ->`.  `X.binder((sink) ->
  ... sink(42)... sink(err,true)`. The end function is to signal
  stream end. `f` can optionally return an unsubscribe function which
  will be called when the event stream ends.
* **def = X.defer()** creates a deferred value `def`.
* **def.resolve(v)** to resolve the deferred with value `v`.
* **def.reject(e)** to reject the deferred with reason `e`.
* **def.push(v)** to push a value down the chain.
* **def.pushError(e)** to push an error down the chain.
* **p = def.promise** to get the promise from the deferred.

### State

* **p.isEnded()** tells whether the stream has been ended.
* **p.isPending()** tells whether the promise is pending. Equivalent to `!p.isEnded()`.
* **p.isFulfilled()** tells whether the promise is resolved.
* **p.isRejected()** tells whether the promise is rejected.
* **p.endOnError()** makes stream stop on first encountered
  error. Returns self.

### Chaining

* **p.then/map(fx[,fe])** attaches `fx` to receive value pushed down
  the chain. Optionally attaches `fe` to receive errors.
* **p.fail/catch(fe)** attaches `fe` to receive errors.
* **p.always/finally/fin(f)** attaches `f` to receive both values and
  errors. The signature for `f` is `(v, isError) ->` where the second
  argument is a boolean telling whether the received value was an
  error.
* **p.serial(fx[,fe])** exactly like `then/map` but ensures only one
  argument is executed at a time. Additional events are buffered up
  and executed one by one. See section on
  [everything being parallel](#everything-is-parallel).
* **p.once(fx)** promise for the first event/value from a
  stream/promise. Automatcially ends when first value is received.
* **p.settle(fx[,fe])** promise for the last event/value from a
  stream/promise. will effectively block a stream to settle before
  releasing. arguments like `.then`

### Arrays and Objects

* **p.each/forEach(fx)** attached `fx` to receive values. If the value is
  an array, it will invoke `fx` one by one. I.e. `[a0,a1,a2]` will
  invoke `fx(a0)`, `fx(a1)`, `fx(a2)`
* **p.singly/oneByOne(fx)** serialized version of `each`. Each
  value in the array is fed to the function only when the last value
  is finished. This mainly makes a difference for deferreds. See
  section explaining
  [each and singly](#foreach-has-a-serial-pitfall).
* **p.spread(fx)** attaches `fx` to receive values. If the value is an
  array, the array will be destructured to arguments in
  `fx`. I.e. `[a0,a1,a2]` will invoke `fx(a0, a1, a2)`. Non-array
  values will be invoked as first argument (`f(v)`).
* **p.all(fx)** attaches `fx` to receive resolved arrays/objects. If
  the value to be executed is an array of promises `[p1,p2,...]`, `fx`
  will only be invoked when all promises are resolved and will be
  receving an array with the *first* resolved values. For objects the
  function inspects each top level property (no deep inspection).
  `{a:p1,b:p2,...}` will result in an object with the resolved values
  bound to the same keys. Any promise failing will abort and reject
  with the error of that promise. For streams it ensures there is *a*
  pushed value, it keeps the *first one* received regardless of there
  being more.
* **X.all(v)** same as `X(v).all()`.
* **p.snapshot(fx)** like `.all`, but uses *current value* instead of
  first. See section about the difference between
  [all or snapshot](#all-or-snapshot).
* **X.snapshot** same as `X(v).snapshot()`.
* **X.oi(f)** chaining helper function with signature `(i,o)`. See
  [oi doc](oi.md).

### Multiple

* **X.merge(s1, s2, ...)** merges the variable number of
  promises/streams to one. The resulting stream will end when all
  parts have ended.

### Filtering

* **p.filter(f)** apply function `f` to each value. If `f` returns a
  truthy, the original value will be released down the chain.
* **p.find(f)** exactly like `filter`. but only the first value is
  released down the chain, and step is closed.

## Everything is parallel

Every operation in XQ is potentially executed in parallel (in a
process.nextTick). For non-deferred values this is mostly never
noticable.

The result of this operation will come out in the order of the array.

```coffeescript
X([0,1,2]).each (v) -> v*2
```

There is however one situation with `endOnError` where it may
matter. A somewhat contrived example.

```coffeescript
# This doesn't work as expected!!!

X([0,1,2]).each (v) ->
    throw new Error('fail') if v == 1
.endOnError()
.then (v) ->
  #... will see 0 and 2
```

The user may expect the last `.then` to never receive the 2. However
since all values are fed into `each` in parallel, the error will
happen too late to stop the 2. To fix this use `singly()`.

### Parallel deferreds

When using deferreds the order is not guaranteed.

```coffeescript
url1 = 'http://www.google.com/'
url2 = 'http://github.com/'
url3 = 'http://www.reddit.com/'
X([url1,url2,url3]).each(doRequest) # returns a promise for result
.map (result) ->
  # ... ?
  ```

Depending on how slow the requests were, the `.map` operation will
receive the result in any order. To fix it, we can use `singly()`
which ensures that each url fed to doRequest will return a fulfilled
promise before the result is passed on to `.map`. This however means
each requests will run serially.

### Strategy for unwrapping deferreds

The principle for unwrapping deferreds is to *unwrap on exit* of each
step.

```coffeescript
X(X(42)).then((v) -> X(v)).then (v) -> #... look ma, v is still 42!
```

If we break down this sequence.

1. Each `X()` is a step like all others. It can be thought of as
   `.then (x) -> x` (a bit more involved since it handles errors).
2. `X()` wraps a deferred `X(42)`.
3. On the exit of the outmost `X()`, the inner `X(42)` is unwrapped to
   `42`.
4. `42` is therefor fed into the next `.then`-step and invoked for the
   function `(v) -> X(v)`.
5. That function once again wraps `v` (42) into a `X(v)` which on the
   exit of that same `.then`-step is unwrapped again back to `42`
6. The last `.then`-step is therefore also just fed `42`.

### each has a serial pitfall

When using `each` in combination with arrays of promises, there is
a potential pitfall. `each` is also parallel and does not wait for
one deferred to finish before feeding the next, which means the
following code would execute `doSomething` in parallell for the values
of the array.

```coffeescript
# each does not work serially!
p1 = makePromise()
p2 = makePromise()
p3 = makePromise()

X([p1,p2,p3]).each (p) -> p.then(doSomething)...
```

#### each().serial() is not serial

A mistaken attempt at fixing this would be to use `serial`, as in
`.each().serial (p) ->...` but this does not work. Having no
function to `each` would be the equivalent to `(x) -> x` and any
deferred would be unwrapped on the exit of that `each`-step. This
means all deferred have been unwrapped in parallel already before the
invocation of `.serial()`.

#### singly() does things serially.

`.singly()` (or alias `.oneByOne()`)is a serialized version of
`.each()`.

```coffeescript
# singly is serial
p1 = makePromise()
p2 = makePromise()
p3 = makePromise()

X([p1,p2,p3]).singly (p) -> p.then(doSomething)... # is done one by one

```

It will queue up each value of the array to be executed one after
another. That means `.singly (v) -> X(doSomething(v))` would wait with
feeding another value to the function until the previous has been
unwrapped. The same goes for the non-argument `.singly()`.

## all or snapshot

`.all` takes the first value `.snapshot` takes the current. This can
be illustrated in beautiful yet informative ascii art.

```
                                          .all
  stream1       a3 - a2 - a1 ->           [  ]
  stream2  b3 - b2 - b1 ->                [  ]
  stream3                       c3 - c2 - [c1] ->

```

At this point `.all` has not resolved, only value `c1` in stream3 has
been. For the three streams moving into the `.all` array, only the
first value will be used. Hence when the promise for `.all` resolves,
we will get an array with the values `[a1,b1,c1]`, the *first* three
values of the three streams.

For snapshot however:

```
                    .snapshot
  stream1       a3 - [a2] - a1 ->
  stream2  b3 - b2 - [b1] ->
  stream3            [c3]         c3 - c2 - c1 ->

```

At the point when all incoming streams have a value (stream2 being
the last), both stream1 and stream3 have taken other values. Hence
the snapshot when it resolves is the `current` state `[a2,b1,c3]`.

## Interoperability with other .then-ables

XQ tries to play nice with other promise packages. It can both wrap
and receive other promises.

`X(Q(42)).then (v) -> ...42`

`X().then(-> Q.reject(42)).fail (v) -> ...42`

## Why a hybrid?

I like promises such as [Q](https://github.com/kriskowal/q) I also
like reactive extensions (FRP). However I don't like the API that
comes with libraries such as
[RxJS](https://github.com/Reactive-Extensions/RxJS),
[Bacon.js](https://baconjs.github.io/) etc. My biggest beef is with
something rx-people call `flatMap`.

#### Comparison of Q and Bacon.js

`Q(42).then((v) -> Q(2*v)).then (v) -> ...v is 84`

`Bacon.once(42).map((v) -> Bacon.once(2*v)).flatMap().onValue (v) -> ...v is 84`

For promises we continue a chain with `.then .then .then`. It doesn't
matter whether the returned value in a step is a promise for a value
`Q(2*v)` or a non-deferred.

With regards to the second `.then`, these two chains are equivalent.

`.then(-> 4).then (v) ->`

`.then(-> Q(4)).then (v) ->`

In the rx-world things are not so easy. As long as you just transform
simple (non-deferred) values, you keep using `.map`, however if you
dare returning a deferred value (observable or event stream) you
probably want `.flatMap`.

In XQ `then` == `map`, there is no difference and a deferred value is
just a special case of an event stream.

Another weirdness is the idea of lazy streams. It is very important to
end a rx-style chain with something that "subscribes"
(i.e. `.onValue()`, `.subscribe()`, `.onError()` etc). It could be
argued that this makes a more obvious distinction between functions
and side effects, but I'm still not convinced. I really don't find
myself ever creating random streams that I end up not using (i.e. not
subscribing to). The point of laziness seems pedantic and unnecessary.
