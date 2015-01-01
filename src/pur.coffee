# special value used to indicate no value since we also deal with
# streams of undefined.
INI = {ini:true}

# special value used to indicate stream ends
FIN = {fin:true}

class Defer

    constructor: ->
        @pur = null

    push:   (v) ->
        @pur._exec v, false
    pushError: (e) ->
        @pur._exec e, true
    resolve: (v) ->
        @push v
        @end()
    reject: (e) ->
        @pushError e
        @end()
    end: ->
        @pur._exec FIN, false

cnt = 0

module.exports = class Pur

    constructor: (@_value, @_isError, @_defer) ->
        return new Pur(_value, false) unless this instanceof Pur

        @cnt = cnt++

        # root Pur does simple resolving
        @_f        = (x) -> x
        @_resolver = thenResolver

        @_prev      = null
        @_next      = []
        @_defer.pur = this if @_defer
        @_isEnded   = !@_defer

        # construct with (Pur) is the same as .then
        if _value instanceof Pur
            @_prev     = @_value
            @_value    = INI
            @_isError  = false
            @_prev._addNext this # this may reset _value

    @Defer: Defer
    @reject: (error) -> new Pur(error, true)
    @defer:  (value) -> (new Pur(INI, false, new Defer()))._defer
    @bubble: (err)   -> throw new BubbleWrap(err)

    isEnded: -> @_isEnded

    _exec: (v, isError) ->
#        console.log "#{@cnt}", '_exec', v
        if v == FIN
            @_prev?._removeNext this
            @_isEnded = true
            @_setValue FIN, isError
        else
            try
                unless @_resolver this, @_f, @_args, v, isError
                    @_setValue v, isError
            catch err
                throw err.wrap if err instanceof BubbleWrap
                @_setValue err, true
        this

    _resolver: -> false

    _setValue: (v, isError) ->
        unless @_isEnded and @_value != INI
            @_isError = isError
            @_value = v
        @_forward v, isError

    _forward: (v, isError) ->
        return if v == INI
#        console.log "#{@cnt}", '_forward', @_next.length, v, isError
        @_next.forEach (n) -> n._exec v, isError
        this

    _addNext: (n) ->
#        console.log "#{@cnt}", '_addNext'
        @_next.push n
        n._prev = this
        unless @_value == INI
            n._exec @_value, @_isError
            n._isEnded = @_isEnded
        return n

    _removeNext: (n) ->
        delete n._prev
        @_next.splice i, 1 if i = @_next.indexOf(n) >= 0
        this

    val: ->
        return undefined if @_value == INI
        return @_value

    done: ->
        p = new Pur()
        p._resolver = (s, f, args, v, isError) ->
            Pur.bubble(v) if isError
            return true
        @_addNext p
        return undefined

class BubbleWrap extends Error
    constructor: (@wrap) ->
        super
        @message = 'BubbleWrap'

stepWith = (resolver) -> (_args...) ->
    p = new Pur(INI)
    p._resolver = resolver
    p._args = _args
    return @_addNext p

stepWithF = (resolver) -> (_args..., _f) ->
    p = new Pur(INI)
    p._resolver = resolver
    p._args = _args
    p._f = _f
    return @_addNext p

# value to indicate .always step
ALWAYS = {always:true}

stepResolver = (mode) -> (s, f, args, v, isError) ->
    return false unless mode == ALWAYS or mode == isError
    # array passed to concat is unwrapped
    # [1,2].concat([3,4])   => [1,2,3,4]
    # [1,2].concat([[3,4]]) => [1,2,[3,4]]  // this is what we want
    av = if mode == ALWAYS then [v, isError] else [v]
    r = if args and args.length then f.apply this, args.concat(av) else f.apply this, av
    # unpack resolved value
    (waitFor = (val, isError) ->
        if val instanceof Pur
            val.always (x, isResolvedErr) ->
                waitFor x, isResolvedErr
                null
        else
            s._setValue val, isError
    )(r, false)
    return true

thenResolver   = stepResolver(false)
failResolver   = stepResolver(true)
alwaysResolver = stepResolver(ALWAYS)
allResolver    = (s, f, args, v, isError) ->
    return false
spreadResolver = (s, f, args, v, isError) ->
    # presumably we use spread to unpack an array
    # [1,2].concat([3,4]) => [1,2,3,4]
    # [1,2].concat(3)     => [1,2,3]
    v2 = (args || []).concat v
    f2 = -> f.apply this, v2
    return thenResolver s, f2, null, v2, isError

StepFun = {
    then:   stepWithF(thenResolver)
    fail:   stepWithF(failResolver)
    always: stepWithF(alwaysResolver)
    all:    stepWith(allResolver)
    spread: stepWithF(spreadResolver)
}

Pur::[k] = v for k, v of StepFun

# Some alias

Pur::map = Pur::then
Pur::catch = Pur::fail
Pur::finally = Pur::fin = Pur::always
