chai   = require 'chai'
expect = chai.expect
chai.should()
chai.use(require 'sinon-chai')
{ assert, spy, match, mock, stub, sandbox } = require 'sinon'
Q = require 'q'

X = require '../src/xq'

later = (f) -> setTimeout f, 5

describe 'X', ->

    describe 'value instantiation', ->

        it 'is done X(x)', ->

            px = X(x = 42)
            px.isEnded().should.eql true

        it 'is also ok with nothing', (done) ->

            px = X()
            px.isEnded().should.eql true
            px.then done

        it 'nested 2 levels are fine', (done) ->

            px = X(X(42))
            px.isEnded().should.eql true
            px.then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'nested 3 levels are fine', (done) ->

            px = X(X(X(42)))
            px.isEnded().should.eql true
            px.then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'nested deferred is interesting', (done) ->

            def = X.defer()
            px = X(def.promise)
            c = 42
            px.then (v) ->
                v.should.eql c++
                done() if v == 43
            .done()
            later -> def.push 42
            later -> def.push 43

    describe 'error instantiation', ->

        it 'is done X.reject(e)', ->

            pe = X.reject(e = new Error('wrong'))
            pe.isEnded().should.eql true

        it 'is ok with nothing', (done) ->

            pe = X.reject()
            pe.isEnded().should.eql true
            pe.fail done

    describe 'defer instantiation', ->

        it 'is done X.defer()', ->

            def = X.defer()

        it 'can optionally take an initial value', ->

            def = X.defer(x = 42)

    describe 'def.promise', ->

        it 'is used to get X from def', ->

            def = X.defer()
            expect(def.promise).to.be.instanceof X
            def.promise._def.should.equal def

        it 'should not be ended', ->

            def = X.defer()
            def.promise.isEnded().should.eql false

    describe 'errors', ->

        it 'are silently consumed', ->

            X.reject(42)
            null

        it 'stops the chain with done', ->

            expect(X(42).done()).to.be.undefined

        it 'are reported if .done', (done) ->

            X.reject(e = new Error('fail')).done (->), (v) ->
                v.should.equal e
                done()

        it 'is different for defers with later done', (done) ->

            def = X.defer()
            def.reject('fail')
            def.promise.done (->), (v) ->
                v.should.eql 'fail'
                done()

        it 'is different for defers with done then rejected', (done) ->

            def = X.defer()
            def.promise.done (->), (v) ->
                v.should.eql 'fail'
                done()
            later -> def.reject('fail')

        it 'works fine with deep errors', (done) ->

            X().then ->
                throw new Error('fail')
            .fail (v) ->
                throw v
            .done (->), (v) ->
                done()

    describe '.then', ->

        it 'handles simple values', (done) ->

            X(42).then (v) ->
                v.should.eql 42
                done()

        it 'handles deferred', (done) ->

            def = X.defer()
            def.promise.then (v) ->
                v.should.eql 42
                done()
            def.push 42

        it 'handles then connected after deferred push', (done) ->

            def = X.defer()
            def.push 42
            def.promise.then (v) ->
                v.should.eql 42
                done()

        it 'handles then connected after deferred resolve', (done) ->

            def = X.defer()
            def.resolve 42
            def.promise.then (v) ->
                v.should.eql 42
                done()

        it 'resolves pushed deferreds', (done) ->

            def = X.defer()
            def.promise.then (v) ->
                v.should.eql 42
                done()
            .done()
            def.push X(42)

        it 'resolves already pushed value', (done) ->

            def = X.defer()
            def.push 42
            def.promise.then (v) ->
                v.should.eql 42
                done()

        it 'handles simple transforming chains', (done) ->

            X(42).then (v) ->
                v.should.eql 42
                panda:true
            .then (v) ->
                v.should.eql panda:true
                done()

        it 'is ok to unwrap deferreds', (done) ->

            X().then ->
                X(panda:true)
            .done(->done())

        it 'handles transforming chains with deferred', (done) ->

            X(42).then (v) ->
                v.should.eql 42
                X(panda:true)
            .then (v) ->
                v.should.eql panda:true
                done()
            .done()

        it 'handles transforming chains with later deferred', (done) ->

            X(42).then (v) ->
                v.should.eql 42
                def = X.defer()
                later ->
                    def.resolve panda:true
                def.promise
            .then (v) ->
                v.should.eql panda:true
                panda:42
            .then (v) ->
                v.should.eql panda:42
                done()

        it 'can do transforming chains with root deferred', (done) ->

            def = X.defer()
            def.promise.then (v) ->
                v.should.eql 42
                panda:42
            .then (v) ->
                v.should.eql panda:42
                done()
            later -> def.resolve 42

        it 'can handle repeated events through chain', (done) ->

            def = X.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            .done()
            def.push 42
            def.push 43

        it 'does not get repeated events when def is ended', (done) ->

            def = X.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42
                done()
            def.push 42
            def.end()
            def.push 43

        it 'will not get event for resolved', (done) ->

            def = X.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42
                done()
            def.resolve(42)
            def.push 43

        it 'takes two functions', (done) ->

            def = X.defer()
            def.promise.then(
                (fx = spy ->),
                fe = ->
                    fx.should.have.been.calledOnce
                    fx.should.have.been.calledWith '1'
                    done()
            ).done()
            def.push '1'
            def.pushError '2'

        it 'takes two functions and error in fx propagates down chain', (done) ->

            def = X.defer()
            def.promise.then(
                (fx = spy -> throw 'error'),
                (fe = spy -> done('bad'))
            ).fail (e) ->
                fx.should.have.been.calledOnce
                fe.should.not.have.been.called
                e.should.eql 'error'
                done()
            .done()
            def.push '1'

        it 'takes two functions and error in fe propagates down chain', (done) ->

            def = X.defer()
            def.promise.then(
                (fx = spy -> done('bad')),
                (fe = spy -> throw 'error')
            ).fail (e) ->
                fx.should.not.have.been.called
                fe.should.have.been.calledOnce
                e.should.eql 'error'
                done()
            .done()
            def.pushError '1'

        it 'is aliased to map', ->

            X::then.should.equal X::map


    describe '.then with defered in defereds', ->

        it 'is ok', (done) ->

            def = X.defer()
            def.promise.then (v) ->
                v.should.eql 42
                done()
            .done()
            def2 = X.defer()
            def.push def2.promise
            def2.push 42

        it 'handles deferreds in deferreds', (done) ->

            def = X.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            .done()
            def2 = X.defer()
            def3 = X.defer()
            def2.push def3.promise
            def.push def2.promise
            later -> def3.push 42
            later -> def3.push 43

        it 'handles deferreds created on the fly', (done) ->

            def = X.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 142 + n++
                done() if n == 2
            .done()
            def2 = X.defer()
            def3 = X.defer()
            def2.push def3.promise
            def.push def3.promise.then (v) ->
                defnew = X.defer()
                later -> defnew.resolve v + 100
                defnew.promise
            later -> def3.push 42
            later -> def3.push 43

        it 'handles failed deferreds created on the fly', (done) ->

            def = X.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 142 + n++
                done() if n == 2
            .done()
            def2 = X.defer()
            def3 = X.defer()
            def2.push def3.promise
            def.pushError def3.promise.then (v) ->
                defnew = X.defer()
                later -> defnew.reject v + 100
                defnew.promise
            later -> def3.push 42
            later -> def3.push 43

    describe '.fail', ->

        it 'is invoked for simple rejected', (done) ->

            X.reject(42).fail (v) ->
                v.should.eql 42
                done()

        it 'is not invoked for non rejected', (done) ->

            X(42).then (v) ->
                v.should.eql 42
                done()
            .fail (v) ->
                done('bad')

        it 'is invoked if chained after .then', (done) ->

            X.reject(42).then ->
                done('bad')
            .fail (v) ->
                v.should.eql 42
                done()

        it 'invokes following then if no error', (done) ->

            X.reject(42).fail (v) ->
                v
            .then (v) ->
                v.should.eql 42
                done()

        it 'doesnt invoke any following fail if no error', (done) ->

            X.reject(42).fail (v) ->
                v
            .fail (v) ->
                done('bad')
            .then (v) ->
                v.should.eql 42
                done()

        it 'invokes fail for errors thrown in then', (done) ->

            X(42).then (v) ->
                throw 'failed'
            .then (v) ->
                done('bad')
            .fail (err) ->
                err.should.eql 'failed'
                done()

        it 'can handle repeated errors through chain', (done) ->

            def = X.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            def.pushError 42
            def.pushError 43

        it 'does not get repeated errors when def is ended', (done) ->

            def = X.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 42
                done()
            def.pushError 42
            def.end()
            def.pushError 43

        it 'will not get errors for resolved', (done) ->

            def = X.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 42
                done()
            def.reject(42)
            def.pushError 43

        it 'is aliased to catch', ->

            X::fail.should.equal X::catch

    describe '.always', ->

        it 'is invoked for normal values', (done) ->

            X(42).always (v, isError) ->
                v.should.eql 42
                isError.should.eql false
                done()
            .done()

        it 'is invoked for errors', (done) ->

            X.reject(42).always (v, isError) ->
                v.should.eql 42
                isError.should.eql true
                done()
            .done()

        it 'becomes normal values after in chain', (done) ->

            X.reject(42).always (v) ->
                v.should.eql 42
                v
            .fail ->
                done('bad')
            .then (v) ->
                v.should.eql 42
                done()

        it 'can be event fed both values and errors', (done) ->

            def = X.defer()
            n = 0
            def.promise.always (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            .done()
            def.pushError 42
            def.push 43

        it 'is aliased to fin and finally', ->

            X::always.should.equal X::fin
            X::always.should.equal X::finally

    describe '.spread', ->

        it 'unpacks any incoming array to function arguments', (done) ->

            X([1,2]).spread (a0, a1) ->
                a0.should.eql 1
                a1.should.eql 2
                done()
            .done()

        it 'handles single values', (done) ->

            X(42).spread (a0, a1) ->
                a0.should.eql 42
                expect(a1).to.be.undefined
                done()
            .done()

    describe '.forEach', ->

        it 'turns any incoming array into a series of events', (done) ->

            c = 0
            X([0,1,2,3,4,5]).forEach (v) ->
                v.should.eql c++
                done() if v == 5
            .done()

        it 'does nothing with an empty array', (done) ->

            X([]).forEach (v) ->
                done('bad ' + v)
            .done()
            done()

        it 'passes non arrays down the chain', (done) ->

            X(42).forEach (v) ->
                v.should.eql 42
                done()
            .done()

        it 'no handler is fine', (done) ->

            c = 0
            X([0,1,2,3]).forEach().then (v) ->
                v.should.eql c++
                done() if v == 3
            .done()

    describe '.[step].serial', ->

        it 'has a serial version of .forEach', (done) ->

            def = X.defer()
            c = 0
            X([0,def.promise,2]).forEach.serial().then (v) ->
                v.should.eql c++
                done() if v == 2
            .done()
            later -> def.resolve(1)
            null

        it 'has a serial version of .then', (done) ->

            def = null
            c = 0
            X([0,1,2]).forEach().then.serial f = spy (v) ->
                if v == 1
                    (def = X.defer()).promise
                else
                    v
            .then (v) ->
                v.should.eql c++
                if v == 0
                    f.should.have.been.calledOnce
                if v == 1
                    f.should.have.been.calledTwice
                if v == 3
                    f.should.have.been.calledThrice
                done() if v == 2
            .done()
            later -> def.resolve(1)
            null

        it 'has a serial version of .fail', (done) ->

            def = null
            c = 0
            X([0,1,2]).forEach (v) ->
                throw v
            .fail.serial f = spy (v) ->
                if v == 1
                    (def = X.defer()).promise
                else
                    v
            .then (v) ->
                v.should.eql c++
                if v == 0
                    f.should.have.been.calledOnce
                if v == 1
                    f.should.have.been.calledTwice
                if v == 3
                    f.should.have.been.calledThrice
                done() if v == 2
            .done()
            later -> def.resolve(1)
            null

        it 'has a serial version of .always', (done) ->

            def = null
            c = 0
            X([0,1,2]).forEach (v) ->
                if v == 1
                    throw v
                else
                    v
            .always.serial f = spy (v) ->
                if v == 1
                    (def = X.defer()).promise
                else
                    v
            .then (v) ->
                v.should.eql c++
                if v == 0
                    f.should.have.been.calledOnce
                if v == 1
                    f.should.have.been.calledTwice
                if v == 3
                    f.should.have.been.calledThrice
                done() if v == 2
            .done()
            later -> def.resolve(1)
            null

        it 'has a serial version of .spread', (done) ->

            def = null
            c = 0
            X([0,1,2]).forEach (v) ->
                [v,v]
            .spread.serial f = spy (v1, v2) ->
                v1.should.eql v2
                if v1 == 1
                    (def = X.defer()).promise
                else
                    v1
            .then (v) ->
                v.should.eql c++
                if v == 0
                    f.should.have.been.calledOnce
                if v == 1
                    f.should.have.been.calledTwice
                if v == 3
                    f.should.have.been.calledThrice
                done() if v == 2
            .done()
            later -> def.resolve(1)
            null

    describe '.onEnd', ->

        it 'is called when stream ends for promises', (done) ->

            X().onEnd -> done()

        it 'is called for deferred promise', (done) ->

            (def = X.defer()).promise.onEnd -> done()
            later -> def.resolve 1

        it 'waits until end of stream', (done) ->

            (def = X.defer()).promise.onEnd f = spy -> done()
            later -> def.push 0
            later -> def.push 1
            later -> def.push 2
            later -> f.should.not.have.been.calledOnce
            later -> def.end()

    describe '.filter', ->

        it 'releases the original value if step function is true', (done) ->

            c = 1
            X([0,1,2,3]).forEach().filter (v) ->
                v % 2 == 1
            .then (v) ->
                v.should.eql c
                c += 2
                done() if v == 3
            .done()

        it 'releases the original value if step function is truthy', (done) ->

            n = 0
            ref = [1, 'a', true, {}]
            X([0,1,'','a',false,true,undefined,{}]).forEach().filter (v) ->
                v
            .then (v) ->
                v.should.eql ref[n++]
                done() if n == 3
            .done()

        it 'releases the original if a deferred value is truthy', (done) ->

            n = 0
            ref = [1, 'a', true, {}]
            X([0,1,'','a',false,true,undefined,{}]).forEach().filter (v) ->
                def = X.defer()
                later -> def.resolve(v)
                def.promise
            .then (v) ->
                v.should.eql ref[n++]
                done() if n == 3
            .done()

        it 'releases errors in filter function', (done) ->

            X().filter (v) ->
                v() # undefined
            .fail (err) ->
                done()
            .done()

        it 'skips errors', (done) ->

            X.reject('fail').filter (v) ->
                done('bad')
            .fail (err) ->
                err.should.eql 'fail'
                done()
            .done()

    describe 'other then-able', ->

        it 'can wrap another resolved then-able', (done) ->

            X(Q(42)).then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'can wrap another rejected then-able', (done) ->

            X(Q.reject(42)).fail (v) ->
                v.should.eql 42
                done()
            .done()
            null

        it 'can wrap as deferred and resolve', (done) ->

            X((def = Q.defer()).promise).then (v) ->
                v.should.eql 42
                done()
            .done()
            later -> def.resolve 42

        it 'can wrap as deferred and reject', (done) ->

            X((def = Q.defer()).promise).fail (v) ->
                v.should.eql 42
                done()
            .done()
            later -> def.reject 42

        it 'can receive as result in .then', (done) ->

            X().then (v) ->
                Q(42)
            .then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'can receive as rejected result in .then', (done) ->

            X().then (v) ->
                Q.reject(42)
            .fail (v) ->
                v.should.eql 42
                done()
            .done()

        it 'can receive as deferred in .then', (done) ->

            def = null
            X().then (v) ->
                def = Q.defer()
                def.promise
            .then (v) ->
                v.should.eql 42
                done()
            .done()
            later -> def.resolve 42

        it 'can receive as rejected deferred in .then', (done) ->

            def = null
            X().then (v) ->
                def = Q.defer()
                def.promise
            .fail (v) ->
                v.should.eql 42
                done()
            .done()
            later -> def.reject 42
