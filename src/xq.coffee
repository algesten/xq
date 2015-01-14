
# special value for promise not yet having a value. this is since we
# handled undefined as well.
INI = {ini:0}

# value used to propagate through promise chain to signal end.
FIN = {fin:0}

# value that indicates no value.
NVA = {nva:0}

cnt = 0

module.exports = class X

    _value:     INI      # the current value
    _isError:   false    # whether the value is an error
    _isEnded:   false    # whether stream is ended
    _isEnding:  false    # something indicated stream is ending.
    _type:      'root'   # type of promise (then, fail, always etc)
    _resolver:  null     # the resolver for this step
    _fx:        null     # function for resolving a value
    _fe:        null     # function for resolving an error
    _prev:      null     # the previous promise in a chain
    _next:      null     # the next promises in a chain
    _execCount: 0        # number of (unresolved) executing events.
    _serial:    false    # whether events are @_exec serialized
    _head:      null     # head of linked list of events to execute (in serial mode)
    _tail:      null     # tail of linked list of events to execute (in serial mode)
    _onEnd:     null     # array of listeners to stream end
    _endOnError: false   # tells whether we stop on first error.

    inspect: ->
        v = if @_value == INI then '_' else @_value + ''
        "{#{@_type}#{@_cnt}: v:#{v}, err:#{@_isError}, "+
        "end:#{@_isEnded}, exec:#{@_execCount}, ser:#{@_serial}}"

    constructor: (v) ->
        return new X(v) unless this instanceof X

        @_cnt = cnt++

        if v == INI
            @_value = INI
        else
            isError = a if typeof (a = arguments[1]) == 'boolean'
            if isError then @_reject(v) else @_resolve(v)
        this

    @reject: (reason) -> new X(reason, true)

    @resolver: (resolver) ->
        def = (new X(INI))._defer()
        resolver ((v) -> def.resolve(v);undefined),((e) -> def.reject(e);undefined)
        return def.promise

    @binder: (binder) ->
        def = (new X(INI))._defer()
        sink = (v, isError) ->
            if isError then def.pushError v else def.push v
            return undefined
        ender = ->
            def.end()
            return undefined
        unsub = binder sink, ender
        def.promise.onEnd unsub if typeof unsub == 'function'
        return def.promise

    @defer: (v) -> new X(INI)._defer(v)

    isPending:   -> not @_isEnded
    isEnded:     -> @_isEnded
    isRejected:  -> @_isEnded and @_isError
    isFulfilled: -> @_isEnded and not @_isError

    # make a facade
    _defer: (v) ->
        @_push v if v isnt undefined
        _this = this
        @_def || @_def = {
            push:      _this._push
            pushError: _this._pushError
            resolve:   _this._resolve
            reject:    _this._reject
            end:       _this._end
            promise:   _this
            toString: -> '[object Defer]'
        }

    # deliberately bound methods
    _push:      (v) => @_exec v, false
    _pushError: (e) => @_exec e, true
    _resolve:   (v) => @_push(v)._end()
    _reject:    (e) => @_pushError(e)._end()
    _end:           => @_exec FIN, false

    _exec: (v, isError, fromQueue) -> # deliberate bind
#        console.log 'exec', v, isError, @inspect()
        # no more pushing to finished value
        return this if @_isEnded or (@_isEnding and !fromQueue)
         # last value sets isEnded and is propagated
        if v == FIN
            @_isEnding = true
            @_doEnd() if @_execCount == 0 and !@_head?.next
            return this
        if @_serial and @_execCount > 0
            @_enqueue v, isError
            return this
        @_execCount++
        unless @_resolver @_fx, @_fe, v, isError, @_resolverExit
            # resolver did not handle the value => set incoming
            @_resolverExit v, isError, true
        this

    # enqueue event in linked list
    _enqueue: (v, isError) ->
#        console.log '_enqueue', v, isError, @inspect()
        unless @_head
            @_head = next:null
            @_tail = @_head
        @_tail = @_tail.next = {next:null,v,isError}

    # pick head of linked list of events
    _nextEvent: ->
        return null unless @_head and @_head.next
        return @_head = @_head.next

    # queues the next event for execution in nextTick.
    _execNext: ->
        if @_execCount == 0 and next = @_nextEvent()
            @_exec next.v, next.isError, true
        return this

    # the no op resolver is default
    _resolver: (fx, fe, v, isError, cb) ->
#        console.log '_resolver', v, isError, @inspect()
        # root resolver does unwrap
        unwrap v, isError, cb
        return true

    # decreases exec count and sets the value.
    _resolverExit: (v, isError, ended) => # deliberate bind
#        console.log 'resolverExit', v, isError, ended, @inspect()
        @_execCount-- if ended
        @_setValue v, isError
        endingAndNoMore = @_isEnding and @_execCount == 0 and !@_head?.next
        endingOnError = isError and @_endOnError
        @_doEnd() if endingAndNoMore or endingOnError
        @_execNext()

    # does the actual ending of a promise. may be called deferred if
    # promise is waiting to resolve.
    _doEnd: => # deliberate bind
#        console.log 'doEnd', @inspect()
        return this if @_isEnded # only end once

        @_isEnded = true
        @_prev?._removeNext this

        # clear state
        @_head = @_tail = null

        # invoke on end listeners
        v = @_value
        isError = @_isError
        errs = (safeCall f, v, isError for f in @_onEnd) if @_onEnd
        firstErr = errs.reduce(((prev, cur) -> prev || cur), null) if errs

        # forward the end
        @_forward FIN, false

        # throw any errors from listeners
        setTimeout (-> throw firstErr if firstErr), 0
        return this

    # sets the value and propagates to chained promises
    _setValue: (v, isError) ->
#        console.log 'setValue', v, isError, @inspect()
        # ended takes no more values and NVA is emitted from some
        # resolver to indicate no value.
        return this if @_isEnded or v == NVA
        @_value   = v
        @_isError = isError
        @_forward v, isError

    # propagates the given value/error to chained promises _exec
    # functions.
    _forward: (v, isError) ->
#        console.log 'forward', v, isError, @inspect()
        return this unless @_next?.length
        @_next.forEach (n) -> n._exec v, isError
        this

    # Adds the given chained promise to this one. Returns the chained.
    _addNext: (n) ->
#        console.log 'addNext', n._type, @inspect()
        @_next = [] unless @_next
        @_next.push n
        n._prev = this
        unless @_value == INI
            n._exec @_value, @_isError
            n._exec FIN, false if @_isEnded and not n._isEnded
        return n

    # Removes the given chained promise from this one.
    _removeNext: (n) ->
        delete n._prev
        @_next.splice i, 1 if i = @_next.indexOf(n) >= 0
        this

    # adds an on end listener.
    onEnd: (f) ->
#        console.log 'onEnd', @inspect()
        @_onEnd = [] unless @_onEnd
        @_onEnd.push f
        err = safeCall f, @_value, @_isError if @_isEnded
        throw err if err
        this

    # stops the stream from executing any more values on first error.
    endOnError: ->
        @_endOnError = true
        this

    # immediately stops the stream
    stop: -> @_doEnd()

    toString: -> '[object Promise]'

X.toString = -> '[object X]'

# to call a method and ignore errors
safeCall = (f, args...) ->
    try
        f args...
        undefined
    catch err
        return err

# test if the given object is .then-able, and make damn sure
# we only check .then once.
isThenable = (o, onErr) ->
    try
        return false unless o?
        return false unless typeof o in ['object', 'function']
        t = o.then
        if typeof t == 'function' then t else false
    catch err
        onErr err
        # then accessor threw error, but that means it existed.
        return true
# test if object is X or thenable
isDeferred = (o) -> o instanceof X or isThenable(o)

# mode for finally/fin/always
ALWAYS = {always:0}

# helper for doing process.nextTick in a platform independent way.
nextTick = require '../lib/nexttick'

# Creates .then-style resolvers (then, fail, always).
makeResolver = (mode) -> (fx, fe, v, isError, cb) ->
    f = if mode == ALWAYS or mode == isError
        fx
    else if mode == false and isError == true
        fe
    return false unless f
    _this = this
    schedule = if @_immediate then (task) -> task() else nextTick
    schedule ->
        try
            r = f.apply undefined, if mode == ALWAYS then [v, isError] else [v]
            throw new TypeError('f returned same promise') if r == _this
            unwrap r, false, cb
        catch err
            unwrap err, true, cb
    return true

# Makes a new promise chained off this with given resolver.
unitFx = (x) -> x
unitFe = (e) -> throw e
stepWith = (type, resolver, twoF, finish, serial, immediate) -> (fx, fe) ->
    fx = unitFx unless typeof fx == 'function'
    fe = unitFe unless typeof fe == 'function'
    p = new X(INI)
    p._type = type
    p._resolver = resolver
    p._fx = fx
    p._fe = fe if twoF
    p._serial = !!serial
    p._immediate = !!immediate
    @_addNext p
    return if finish then undefined else p

# create standard step functions and their aliases
thenResolver   = makeResolver false
failResolver   = makeResolver true
alwaysResolver = makeResolver ALWAYS
X::then    = X::map   = stepWith 'then', thenResolver, true
X::fail    = X::catch = stepWith 'fail', failResolver
X::always  = X::fin = X::finally = stepWith 'always', alwaysResolver
# internal always-resolver to not confuse things
X::_always = stepWith 'always', alwaysResolver, true, false, false, true

# spread is like then
X::spread = stepWith 'spread', (fx, fe, v, isError, cb) ->
    # presumably we use spread to unpack an array in v, but we handle
    # single values too.
    argv = if Array.isArray(v) then v else [v]
    f = -> fx.apply undefined, argv
    return thenResolver.call this, f, undefined, v, isError, cb

# done method is special, because it bubbles any exceptions.
doneResolver = (fx, fe, v, isError, cb) ->
    if isError and not fe or fe == unitFe
        fe = -> setTimeout (-> throw (if v instanceof Error then v else new Error(v))), 0
        fe = process.domain.bind(fe) if process?.domain?
    return thenResolver.call this, fx, fe, v, isError, cb
X::done = stepWith 'done', doneResolver, true, true

# forEach emits array elements one by one
forEachResolver = (fx, fe, v, isError, cb) ->
    if isError or !Array.isArray(v)
        return thenResolver.call this, fx, fe, v, isError, cb
    # zero length array means we emit no value down the chain.
    if v.length == 0
        cb NVA, false, true
        return true
    # increase exec count with the amount of values we intend to emit
    # -1 for the one already counted up when entering _exec.
    @_execCount += (v.length - 1) unless @_serial
    for x in v
        if @_serial
            @_enqueue x, isError
        else
            unless thenResolver.call this, fx, fe, x, false, cb
                cb x, false, false
    # kick of serial execution
    cb NVA, false, true if @_serial
    return true
X::forEach = X::each     = stepWith 'forEach', forEachResolver, false, false, false
# The serial version
X::singly  = X::oneByOne = stepWith 'singly',  forEachResolver, false, false, true

# resolver to handle .filter (x) ->. if returned value is truthy,
# value is released down the chain.
filterResolver = (fx, fe, v, isError, cb) ->
    return false if isError
    filterCb = (vb, isError, ended) ->
        if isError
            cb vb, isError, ended
        else
            if vb == NVA
                cb NVA, false, ended
            else if vb # truthy
                cb v, false, ended # release original value
            else
                cb NVA, false, ended
    return thenResolver.call this, fx, fe, v, isError, filterCb
X::filter = stepWith 'filter', filterResolver

# resolver for handling deferreds in [] and {}
allResolver = (snapshot) -> (fx, fe, v, isError, cb) ->
    if Array.isArray v
        # an array
        arr = v
        val = (k) -> k
        result =  Array.apply(null, Array(v.length)).map -> NVA
        unsubs = []
        r = (k, idx, val, unsub) ->
            isNew = result[idx] == NVA
            return false unless snapshot or isNew
            result[idx] = val
            unsubs.push unsub
            isNew
    else if typeof v == 'object' and not isDeferred(v)
        # a plain object
        arr = Object.keys(v)
        val = (k) -> v[k]
        result = {}
        unsubs = []
        r = (k, idx, val, unsub) ->
            isNew = !result.hasOwnProperty(k)
            return false unless snapshot or isNew
            result[k] = val
            unsubs.push unsub
            isNew
    if arr?.reduce ((prev,cur) -> prev || isDeferred(val(cur))), false
        done = 0
        _this = this
        stop = false
        arr.every (k, idx) ->
            a = val(k)
            unwrap a, false, (ua, isError, ended, unsub) ->
                return if stop
                if isError
                    stop = true
                    cb ua, true  # break on first error
                    return
                return if ua == NVA
                done++ if r k, idx, ua, unsub
                if arr.length == done
                    stop = true
                    # unsubscribe all wrapped
                    u() for u in unsubs
                    return thenResolver.call _this, fx, fe, result, false, cb
                null
            return true
        return true
    return thenResolver.call this, fx, fe, v, isError, cb
X::all = stepWith 'all', allResolver(false)
X.all = (v) -> X(v).all()
X::snapshot = stepWith 'snapshot', allResolver(true)
X.snapshot = (v) -> X(v).snapshot()

# events stream to promise for first value
onceResolver = (fx, fe, v, isError, cb) ->
    _this = this
    # eat up
    return true if @_once
    @_once = true
    endCb = (v, isError, ended, unsub) ->
        cb v, isError, true
        _this._doEnd()
        unsub()
    return thenResolver.call this, fx, fe, v, isError, endCb
X::once = stepWith 'once', onceResolver

# a serial resolver is like a then but one argument at a time.
X::serial = stepWith 'serial', thenResolver, true, false, true

# a merge of streams
X.merge = (args...) -> X.binder (sink, end) ->
    ended = 0
    all = []
    for a in args
        all.push(X(a).always (v, isError) ->
            sink v, isError
            null
        .onEnd ->
            end() if ++ended == args.length)
    -> p._doEnd() for p in all

# Recursively unwrap the given value. Callback when we got to the
# bottom of it.
unwrap = (v, isError, cb, ended = true, prevUnsub = (->)) ->
    unsub = prevUnsub
    if v instanceof X
        al = v._always (v, isError) ->
            unsub = -> prevUnsub(); al._doEnd()
            unwrap v, isError, cb, false, unsub
            return null # important or we get endless loops
        v.onEnd -> unwrap NVA, false, cb, ended, unsub
    else if t = isThenable v, ((err) -> unwrap err, true, cb, ended, unsub)
        return if t == true # err handler ran
        got = false
        try
            f = (isError) ->
                (x) ->
                    return if got; got = true; unwrap x, isError, cb, ended, unsub
            t.call v, f(false), f(true)
        catch err
            return if got
            got = true
            unwrap err, true, cb, ended, unsub
    else
        cb v, isError, ended, unsub

# retry the promise producing function f at most max times.
X.retry = (max, delay, f) ->
    X._retry = new (require './retry') unless X._retry
    X._retry.try max, delay, f
