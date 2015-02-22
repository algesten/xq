tick = require 'next-tick'

I   = (x) -> x
T   = (x) -> throw x
ini = ini:1
fin = fin:1

cnt = 0

module.exports = class X

    parent:   undefined  # parent step
    childs:   undefined  # next steps
    value:    undefined  # resolved value of step
    iserr:    false      # whether step was an error
    ended:    false      # whether promise is ended
    endonerr: false      # whether we end on first error

    constructor: (v) ->
        return new X(v) unless this instanceof X
        @cnt = cnt++
        @value = ini
#        console.log 'cons', v, @inspect()
        @step = thenstep I, T # root step
        if arguments.length
            @_push v, arguments[1]
            @_push fin

    inspect: -> "{#{@cnt},v:#{@value},iserr:#{!!@iserr},ended:#{!!@ended}}"

    @resolve: (v) -> new X(v)
    @reject:  (v) -> new X(v, true)

    @defer: -> new Defer()

    @resolver: (f) ->
        def = @defer()
        f ((v) -> def.resolve(v)), ((e) -> def.reject(e))
        def.promise

    @binder: (binder) ->
        def = @defer()
        sink = (v, iserr) ->
            if iserr then def.shove v else def.push v
            undefined
        ender = ->
            def.end()
            undefined
        unsub = binder sink, ender
        def.promise.settle unsub if typeof unsub == 'function'
        def.promise

    isPending:   -> not @ended
    isEnded:     -> @ended
    isRejected:  -> @ended and @iserr
    isFulfilled: -> @ended and not @iserr

    _push:  (v, iserr) -> @_exec v, iserr

    _set: (v, iserr) =>
 #       console.log 'set', v, !!iserr, @inspect()
        return if @ended
        if v == fin
            @ended = true
        else
            @value = v
            @iserr = iserr
        @_forward v, iserr
        undefined

    _forward: (v, iserr) ->
        return unless @childs
        for child in @childs
            child._exec(v, iserr)
        undefined

    _exec: (v, iserr) ->
#        console.log 'exec', v, !!iserr, @inspect()
        return if v == ini
        return if @ended
        @step v, iserr, @_set
        undefined

    endOnError: ->
        @endonerr = true
        this

    stop: ->
        @_set fin
        this

    toString: -> '[object Promise]'


class Defer
    constructor: ->   @promise = new X()
    resolve:   (v) -> @promise._push(v);       @promise._push(fin)
    reject:    (e) -> @promise._push(e, true); @promise._push(fin)
    push:      (v) -> @promise._push(v)
    shove:     (e) -> @promise._push(e, true)
    end:           -> @promise._push(fin)
    toString: -> '[object Defer]'

Defer::pushError = Defer::shove


stepwith = (f) -> (fx, fe) ->
    @childs = [] unless @childs
    @childs.push (next = new X())
    next.parent = this
    next.step = f fx, fe
    next._exec @value, @iserr
    next


unself = (_this, v) -> if v == _this then throw new TypeError("Promise returned self") else v

thenstep = (fx, fe) ->
    isfin = false
    count = 0
    (v, iserr, out) ->
        _this = this
        f = if iserr then fe else fx
        wout = (v, iserr) ->
            --count
            out v, iserr
            out fin if count == 0 and isfin or iserr and _this.endonerr
        tick ->
            if v == fin
                if count == 0
                    out fin
                else
                    isfin = true
            else if typeof f == 'function'
                ++count
                try
                    unravel unself(_this,f(v),), wout
                catch e
                    unravel unself(_this,e), (w) -> wout w, true
            else
                ++count
                wout v, iserr
        undefined

X::then = X::map = stepwith thenstep
X::fail = X::catch = stepwith (fe) -> thenstep null, fe

X::always = X::finally = X::fin = stepwith (fx) -> thenstep fx, (e) -> fx e, true

X::settle = stepwith (fx, fe) ->
    lastv     = ini
    lastiserr = false
    (v, iserr, out) ->
        if v == fin
            thenstep(fx, fe) lastv, lastiserr, out
        else
            lastv = v
            lastiserr = iserr

aserror = (w) -> if w instanceof Error then w else new Error(w)
X::done = (ifx, ife) ->
    f = (fx, fe) ->
        _then = thenstep fx, fe
        (v, iserr, out) -> _then v, iserr, (w, wiserr) ->
            if wiserr
                tick -> throw aserror(w)
    stepwith(f).call(this, ifx, ife)
    undefined


X::each = X::forEach = stepwith (fx) ->
    _then = thenstep fx
    (v, iserr, out) ->
        if Array.isArray v
            for x in v
                _then x, iserr, out
        else
            _then v, iserr, out


X::serial = stepwith (fx, fe) ->
    _then = thenstep fx, fe
    head = next:null
    tail = head
    count = 0
    (v, iserr, out) ->
        take = ->
            head = head.next
            ++count
            _then head.v, head.iserr, wout
        wout = (v, iserr) ->
            --count
            out v, iserr
            take() if head.next
        tail = tail.next = {next:null, v, iserr}
        take() if count == 0

onesie = (g, f) ->
    -> return if g.called; g.called = 1; f arguments...

unravel = (v, out) ->
    try
        return out v unless v   # false, 0, '', null, undefined
        return out v unless typeof v in ['object', 'function']
        if v instanceof X
            v.always (w, iserr) -> out w, iserr
            v.settle -> out fin
        else if typeof (t = v.then) == 'function'
            onein  = {}
            oneout = {}
            un = (isrej) -> onesie onein, (w) -> unravel w, onesie oneout, (u, iserr) ->
                out u, (isrej || iserr)
                out fin
            try
                t.call v, un(false), un(true)
            catch e
                un(true)(e)
        else
            out v
    catch e
        out e, true
    undefined
