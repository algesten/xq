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

    isEnded: -> @_isEnded

    _exec: (v, isError) ->
        return if @_value == FIN
#        console.log "#{@cnt}", '_exec', v
        if v == FIN
            @_setValue FIN
            @_prev?._removeNext this
            @_forward v, false
        else
            unless @_resolver
                @_setValue v, isError
                @_forward v, isError
            else
                try
                    @_resolver this, @_f, @_args, v, isError
                catch err
                    @_setError err
                    @_forward err, true
        this

    _setValue: (v, isError) ->
        @_isError = !!isError
        @_value = v

    _setError: (e) ->
        @_isError = true
        @_value = e

    _forward: (v, isError) ->
        return if v == INI or !@_next.length
#        console.log "#{@cnt}", '_forward', v
        if @_next.length
            @_next.forEach (n) -> n._exec v, isError
        else
            throw v if isError
        this

    _addNext: (n) ->
#        console.log "#{@cnt}", '_addNext'
        @_next.push n
        n._prev = this
        n._exec @_value, @_isError unless @_value == INI
        n

    _removeNext: (n) ->
        delete n._prev
        @_next.splice i, 1 if i = @_next.indexOf(n) >= 0
        this


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
    if args and args.length then f.apply this, args.concat(v) else f.call this, v

thenResolver   = (s, f, args, v, isError) ->
    return s._forward v, isError if isError
#    console.log "#{s.cnt}", '_thenResolve', f+ ''
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
    return s

failResolver   = (s, f, args, v, isError) ->
    return s._forward v, isError unless isError
#    console.log "#{s.cnt}", '_failResolve'
alwaysResolver = (s, f, args, v, isError) ->
allResolver    = (s, f, args, v, isError) ->
spreadResolver = (s, f, args, v, isError) ->
valResolver    = (s, f, args, v, isError) ->

StepFun = {
    then:   stepWithF(thenResolver)
    fail:   stepWithF(failResolver)
    always: stepWithF(alwaysResolver)
    all:    stepWith(allResolver)
    spread: stepWithF(spreadResolver)
    val:    stepWith(valResolver)
}

Pur::[k] = v for k, v of StepFun
