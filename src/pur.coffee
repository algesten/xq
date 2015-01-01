# special value used to indicate no value since we also deal with
# streams of undefined.
INI = {ini:true}

# special value used to indicate stream ends
FIN = {fin:true}

class Defer

    constructor: ->
        @pur = null

    push:   (v) =>
        @pur._exec v, false
    pushError: (e) =>
        @pur._exec e, true
    resolve: (v) =>
        @push v
        @end()
    reject: (e) =>
        @pushError e
        @end()
    end: =>
        @pur._exec FIN, false

cnt = 0

module.exports = class Pur

    constructor: (@_value, @_isError, @_defer) ->
        return new Pur(_value, false) unless this instanceof Pur

        @cnt = cnt++

        # construct with (Pur, resolver)
        if _value instanceof Pur
            @_prev     = @_value
            @_resolver = @_isError
            @_setValue undefined

        @_prev      = null
        @_next      = []
        @_isEnded   = false
        @_defer.pur = this if @_defer
        @_isEnded   = true unless @_defer

    @Defer: Defer
    @reject: (error) -> new Pur(error, true)
    @defer:  (value) -> (new Pur(INI, false, new Defer()))._defer
    @bubble: (err)   -> throw new BubbleError(err)

    isEnded: -> @_isEnded

    _exec: (v, isError) ->
        return if @_value == FIN
#        console.log "#{@cnt}", '_exec', v
        if v == FIN
            @_setValue FIN
            @_prev?._removeNext this
            @_forward v, false
        else
            try
                unless @_resolver this, @_f, @_args, v, isError
                    @_setValue v, isError
                    @_forward v, isError
            catch err
                throw err.wrap if err instanceof BubbleError
                @_setError err
                @_forward err, true
        this

    _resolver: -> false

    _setValue: (v, isError) ->
        @_isError = !!isError
        @_value = v

    _setError: (e) ->
        @_isError = true
        @_value = e

    _forward: (v, isError) ->
        return if v == INI
#        console.log "#{@cnt}", '_forward', @_next.length, v, isError
        @_next.forEach (n) -> n._exec v, isError
        this

    _addNext: (n) ->
#        console.log "#{@cnt}", '_addNext'
        @_next.push n
        n._prev = this
        n._exec @_value, @_isError unless @_value == INI
        return n

    _removeNext: (n) ->
        delete n._prev
        @_next.splice i, 1 if i = @_next.indexOf(n) >= 0
        this

    val: ->
        return undefined if @_value in [FIN, INI]
        return @_value

    done: ->
        p = new Pur()
        p._resolver = (s, f, args, v, isError) ->
            Pur.bubble(v) if isError
            return true
        @_addNext p
        return undefined

class BubbleError extends Error
    constructor: (@wrap) -> super

stepWith = (resolver) -> (_args...) ->
    p = new Pur(INI)
    p._resolver = resolver
    p._args = _args
    @_addNext p

stepWithF = (resolver) -> (_f, _args...) ->
    p = new Pur(INI)
    p._resolver = resolver
    p._f = _f
    p._args = _args
    @_addNext p

# invoke f with args prepended to v
invokeWithArgs = (f, args, v) ->
    if args and args.length then f.apply this, args.concat([v]) else f.call this, v

# value to indicate .always step
ALWAYS = {always:true}

stepResolver = (mode) -> (s, f, args, v, isError) ->
    return false unless mode == ALWAYS or mode == isError
    r = invokeWithArgs f, args, v
    if r instanceof Pur
        r.then (x) ->
            s._setValue x
            s._forward x, false
            null
        r.fail (e) ->
            s._setError e
            s._forward e, true
            null
    else
        s._setValue r
        s._forward r, false
    return true

thenResolver   = stepResolver(false)
failResolver   = stepResolver(true)
alwaysResolver = stepResolver(ALWAYS)
allResolver    = (s, f, args, v, isError) ->
    return false
spreadResolver = (s, f, args, v, isError) ->
    v2 = args.concat v
    f2 = -> f.apply this, v2
    return thenResolver s, f2, null, null, v2, isError

StepFun = {
    then:   stepWithF(thenResolver)
    fail:   stepWithF(failResolver)
    always: stepWithF(alwaysResolver)
    all:    stepWith(allResolver)
    spread: stepWithF(spreadResolver)
}

Pur::[k] = v for k, v of StepFun
