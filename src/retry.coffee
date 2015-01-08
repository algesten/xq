X        = require './xq'

extend = (a, b) ->
    a[k] = v for own k, v of b
    return a

module.exports = class Retry

    min:          0
    base:         1.2
    exp:          33
    defaultMax:   5
    defaultDelay: 1000

    constructor: (options) ->
        extend this, options

    delay: (attempt, delay) ->
        @min + Math.floor(delay * Math.pow(@base, Math.min(@exp, attempt)) +
            delay / 2 * Math.random())

    try: (max, delay, f) ->
        _this = this
        if arguments.length == 2
            [max, f] = arguments
            delay = @defaultDelay
        else if arguments.length == 1
            [f] = arguments
            max = @defaultMax
            delay = @defaultDelay
        lastErr = null
        X.binder (sink, end) ->
            do tryAgain = (attempt = 0) ->
                if attempt >= max
                    sink lastErr, true
                    end()
                    return
                p = f()
                firstError = false
                onErr = (err) ->
                    # ignore consecutive errors
                    return if firstError
                    firstError = true
                    lastErr = err
                    if (delay = _this.delay attempt, delay) >= 0
                        setTimeout (-> tryAgain attempt + 1), delay
                    else
                        sink new Error("Abort with #{delay}"), true
                        end()
                    null
                if p instanceof X
                    # allow for streams
                    p.then(sink,onErr).onEnd ->
                        # if it is rejected we are retrying
                        end() unless p.isRejected()
                else
                    # treat as a promise which ends immediatelly
                    p.then ((v) -> sink(v);end()), onErr
                null
            null
