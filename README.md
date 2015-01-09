XQ - Reactive Promises
======================

[![Build Status](https://travis-ci.org/algesten/xq.svg)](https://travis-ci.org/algesten/xq)

XQ is a hybrid between promises and reactive extensions. A simple
clean API modelled on promises with the addition of event streams.

XQ is in its core a Promises/A+ compliant promises implementation, but
it is also a stream.

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
X([1,2,3,4]).forEach(v) ->
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

### Multiple

* **X.merge(s1, s2, ...)** merges the variable number of
  promises/streams to one. The resulting stream will end when all
  parts have ended.

### State

* **p.isEnded()** tells whether the stream has been ended.
* **p.isPending()** tells whether the promise is pending. Equivalent to `!p.isEnded()`.
* **p.isFulfilled()** tells whether the promise is resolved.
* **p.isRejected()** tells whether the promise is rejected.
* **p.onEnd(f)** will call `f` when stream is ended.
* **p.endOnError()** makes stream stop on first encountered error.

### Chaining

* **p.then/map(fx[,fe])** attaches `fx` to receive value pushed down
  the chain. Optionally attaches `fe` to receive errors.
* **p.fail/catch(fe)** attaches `fe` to receive errors.
* **p.always/finally/fin(f)** attaches `f` to receive both values and
  errors. The signature for `f` is `(v, isError) ->` where the second
  argument is a boolean telling whether the received value was an
  error.
* **p.once(fx)** picks the first event/value from a stream/promise and
  turns that into a promise.
* **p.serial(fx[,fe])** exactly like `then/map` but ensures only one
  argument is executed at a time. Additional events are buffered up
  and executed one by one.

### Arrays and Objects

* **p.forEach/each(fx)** attached `fx` to receive values. If the value is
  an array, it will invoke `fx` one by one. I.e. `[a0,a1,a2]` will
  invoke `fx(a0)`, `fx(a1)`, `fx(a2)`
* **p.spread(fx)** attaches `fx` to receive values. If the value is an
  array, the array will be destructured to arguments in
  `fx`. I.e. `[a0,a1,a2]` will invoke `fx(a0, a1, a2)`. Non-array
  values will be invoked as first argument (`f(v)`).
* **p.all(fx)** attaches `fx` to receive resolved arrays/objects. If
  the value to be executed is an array of promises `[p1,p2,...]`, `fx`
  will only be invoked when all promises are resolved and will be
  receving an array with the resolved values. For objects the function
  inspects each top level property (no deep inspection).
  `{a:p1,b:p2,...}` will result in an object with the resolved values
  bound to the same keys. Any promise failing will abort and reject
  with the error of that promise. For streams it ensures there is *a*
  pushed value, it keeps the first one received regardless of there
  being more.
* **X.all(v)** same as `X(v).all()`.

### Filtering

* **p.filter(f)** apply function `f` to each value. If `f` returns a
  truthy, the original value will be released down the chain.

## Everything is parallel

Every operation in XQ is potentially executed in parallel (in a
process.nextTick). For non-deferred values this is mostly never noticable.

The result of this operation will come out in the order of the array.

```coffeescript
X([0,1,2]).forEach (v) -> v*2
```

There is however one situation with `endOnError` where it may
matter. A somewhat contrived example.

```coffeescript
# This doesn't work as expected!!!

X([0,1,2]).forEach (v) ->
    throw new Error('fail') if v == 1
.endOnError()
.then (v) ->
  #... will see 0 and 2
```

The user may expect the last `.then` to never receive the 2. However
since all values are fed into `forEach` in parallel, the error will
happen too late to stop the 2. To fix this use `forEach().serial()`.

### Parallel deferreds

When using deferreds the order is not guaranteed.

```coffeescript
url1 = 'http://www.google.com/'
url2 = 'http://github.com/'
url3 = 'http://www.reddit.com/'
X([url1,url2,url3]).forEach(doRequest) # returns a promise for result
.map (result) ->
  # ... ?
```

Depending on how slow the requests were, the `.map` operation will
receive the result in any order. To fix it, we can use
`forEach().serial()` which ensures that each url fed to doRequest will
return a fulfilled promise before the result is passed on to
`.map`. This however means each requests will run serially.

## Interoperability with other .then-ables

XQ tries to play nice with other promise packages. It can both wrap and receive other promises.

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
