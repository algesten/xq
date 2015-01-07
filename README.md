XQ - Reactive Promises (experimental)
=====================================

XQ is a hybrid between promises and reactive extensions. A simple
clean API modelled on promises with the addition of event streams.

Think of a promise chain, but you can push multiple values down it. `.then == .map`

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

### Chaining

* **p.then/map(fx[,fe])** attaches `fx` to receive value pushed down
  the chain. Optionally attaches `fe` to receive errors.
* **p.fail/catch(fe)** attaches `fe` to receive errors.
* **p.always/finally/fin(f)** attaches `f` to receive both values and
  errors. The signature for `f` is `(v, isError) ->` where the second
  argument is a boolean telling whether the received value was an
  error.

### Arrays

* **p.forEach/each(fx)** attached `fx` to receive values. If the value is
  an array, it will invoke `fx` one by one. I.e. `[a0,a1,a2]` will
  invoke `fx(a0)`, `fx(a1)`, `fx(a2)`
* **p.spread(fx)** attaches `fx` to receive values. If the value is an
  array, the array will be destructured to arguments in
  `fx`. I.e. `[a0,a1,a2]` will invoke `fx(a0, a1, a2)`. Non-array
  values will be invoked as first argument (`f(v)`).

### Filtering

* **p.filter(f)** apply function `f` to each value. If `f` returns a
  truthy, the original value will be released down the chain.


### Serialization

Some methods have serial variants. The serial variant guarantees that
only one value is executed at a time.

* **p.then.serial(fx[,fe])** attaches `fx` and optionally `fe` to
  receive values serially (see `p.then`).
* **p.fail.serial(fe)** attaches `fe` to receive values serially (see `p.fail`).
* **p.always.serial(f)** attaches `f` to receive values serially (see `p.always`).
* **p.forEach.serial(fx)** attaches `fx` to receive values serially (see `p.forEach`).
* **p.spread.serial(fx)** attaches `fx` to receive values serially (see `p.spread`).

## Interoperability with other .then-ables

XQ tries to play nice with other promise packages. It can both wrap and receive other promises.

`X(Q(42)).then (v) -> ...42`

`X().then(-> Q.reject(42)).fail (v) -> ...42`

## Get it

### Download Source

```bash
git clone https://github.com/algesten/xq.git
cd ./xq
```

### Installing with NPM

```bash`
$ npm install xq
...
X = require 'xq'
```

## Why a hybrid?

I like promises such as [Q](https://github.com/kriskowal/q) I also
like reactive extensions (FRP). However I don't like the API that
comes with libraries such as
[RxJS](https://github.com/Reactive-Extensions/RxJS),
[Bacon.js](https://baconjs.github.io/) etc. My biggest beef is with
something rx-people call `flatMap`.

#### Comparison of Q and Bacon.js

`Q(42).then((v) -> Q(2*v)).then (v) -> ...v is 84`

`Bacon.once(42).map((v) -> Bacon.once(2*v)).flatMap (v) -> ...v is 84`

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
