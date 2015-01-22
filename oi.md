OI
==

OI is a helper for passing multiple values through a promise/event
chain.

## Quick. How do I use it?

```
.oi (i, o) ->
    ...
.oi ({a1, a2}, o) ->    # 1. destructure what you need from i
    o.a3 = ...          # 2. assign new promises to o.[name]
.oi ({a1, a3}, o) ->    # 3. use resolved new values and old ones
    ...
```

1. `i` is the input from the previous step which we typically use with
   destructuring assignment.
2. `o` is an empty object to which we can assign new promises/values.
3. the return can be a promise, however the value is ignored.
4. the result of the step is `mixin i, o`. values in o can
   overwrite same names in i.

### Why OI?

When I discovered promises I often found myself saving values in
scoped variables.

```
doSomething = ->
    something = null   # NO!
    another = null     # NOOOO!
    Q().then ->
        someFileOperation()
    .then (_something) ->
        something = _something    # YUCK!
        someDbThing(something.blah)
    .then (_another) ->
        another = _another        # MORE YUCK!
    .then ->
        doStuff(something, another)
    .then ->
        close(something)
    .then ->
        move(another);
```

Those scope variables really bothers me. And are outright wrong for XQ
style event chains where they would overwrite each other.

With XQ I made `X.all()` work for objects as well as arrays, this
opened up for a new style.

*Coffeescript destructuring to the rescue!*

```
doSomething = ->
    X().then ->
        someFileOperation()
    .then (something) ->
        another = someDbThing(something.blah)
        {something, another}
    .all ({something, another}) ->            # Sweet!
        doStuff(something, another).then ->
            {something, another}
    .then ({something, another}) ->
     ...
```

However it's still a bit much to write when every step must explicitly
end with what args are passed to the next, which in turn starts by
just deconstructing the same args.

        {something, another}
    .all ({something, another}) ->

So one morning in yoga practice (ok, bad focus, I know), it came to me.

*OI [choir music]*

```
doSomething = ->
    X().oi (o) ->
        o.something = someFileOperation()
    .oi ({something}, o) ->
        o.another = someDbThing(something.blah)
    .oi ({something, another}, o) ->
        doStuff(something, another)
    .oi ({something}, o) ->
        close(something)
    .oi ({another}, o) ->
        move(another)
```

One can think of `.oi` as a curried function with the following signature

`oi(f)(i)` `:: ((i, o) -> *) -> i -> o`

An implemetation using [fnuc](https://github.com/algesten/fnuc) is:

```
oi = curry (i, f) ->    # fnuc does reverse curry
    o = {}
    r = if f.length == 1 then f(o) else f(i, o)
    X(r).then -> X.all(mixin i, o)
```

This could be used with `X.all()`

```
.all oi (o, {a1}) ->
```

However I made an implementation straight in XQ.
