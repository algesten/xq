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
            px.isEnded().should.be.false
            px.then (v) ->
                v.should.eql c++
            .onEnd ->
                px.isEnded().should.be.true
                done()
            later -> def.push 42
            later -> def.push 43
            later -> def.end()

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

    describe 'def.end()', ->

        it 'is only ending the stream once', (done) ->

            def = X.defer()
            def.promise.onEnd done
            def.end()
            def.end()

    describe '.resolver', (done) ->

        it 'is used to create a resolve a promise resolved by a function', (done) ->

            X.resolver (resolve, reject) ->
                later -> resolve(42)
            .then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'is used to create a resolve a promise rejected by a function', (done) ->

            X.resolver (resolve, reject) ->
                later -> reject(42)
            .fail (v) ->
                v.should.eql 42
                done()
            .done()

        it 'returns undefined on both resolve/reject', (done) ->

            X.resolver (resolve, reject) ->
                expect(resolve(42)).to.be.undefined
                expect(reject(42)).to.be.undefined
                done()
            .done()

    describe '.binder', (done) ->

        it 'is used to bind an event emitter using a sink function', (done) ->

            c = 42
            X.binder (sink) ->
                later -> sink 42
                later -> sink 43
                later -> sink 44
            .then (v) ->
                v.should.eql c++
                done() if v == 44
            .done()

        it 'is possible to use sink function to emit errors', (done) ->

            c = 42
            X.binder (sink) ->
                later -> sink 42, true
                later -> sink 43, true
                later -> sink 44, true
            .fail (v) ->
                v.should.eql c++
                done() if v == 44
            .done()

        it 'receives a second argument which ends the stream', (done) ->

            X.binder (sink, end) ->
                end()
            .onEnd done

        it 'returns undefined on both sink/end', (done) ->

            X.binder (sink, end) ->
                expect(sink(0)).to.be.undefined
                expect(end()).to.be.undefined
                done()

        it 'can optionally return an unsubscribe function', (done) ->

            c = 42
            p = X.binder (sink, end) ->
                later -> sink 42
                later -> sink 43
                later -> sink 44
                later -> end()
                -> done()

            p.then (v) -> v.should.eql c++

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

        it 'propagates the end', (done) ->

            X([0,1,2]).forEach().map (v) ->
                v * 2
            .onEnd done

        it 'waits with end until the end', (done) ->

            c = 0
            p = X().then ->
                def = X.defer()
                later -> def.resolve [0,1,2]
                def.promise
            p.forEach f = spy (v) ->
                v.should.eql c++
            .onEnd ->
                f.should.have.been.calledThrice
                done()

        it 'is aliased to each', ->

            X::forEach.should.equal X::each

    describe '.singly', ->

        it 'turns any incoming array into a series of events, serially', (done) ->

            c = 0
            X([0,1,2,3,4,5]).singly (v) ->
                c++
                c.should.eql 1
                def = X.defer()
                later -> def.resolve v
                def.promise
            .then ->
                c--
            .onEnd done
            .done()

        it 'turns any incoming array which fails serially', (done) ->

            c = 0
            X([0,1,2,3,4,5]).singly (v) ->
                c++
                c.should.eql 1
                def = X.defer()
                later -> def.resolve v
                throw def.promise
            .fail ->
                c--
            .onEnd done
            .done()

        it 'is aliased to oneByOne', ->

            X::oneByOne.should.equal X::singly

    describe '.onEnd', ->

        it 'is called when stream ends for promises', (done) ->

            X().onEnd -> done()

        it 'returns itself', ->

            x = X()
            x.should.equal x.onEnd(->)

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

        it 'waits until end of nested deferred', (done) ->

            innerEnd = null
            c = 0
            X.binder (sink, end) ->
                X(Q([0,1,2])).forEach().then(sink).onEnd innerEnd = spy -> end()
            .then f = spy (v) ->
                v.should.eql c++
            .onEnd ->
                f.should.have.been.calledThrice
                innerEnd.should.have.been.calledOnce
                done()
            .done()

        it.skip 'throws first error encountered in handlers', (done) ->

            lsts = null
            try
                lsts = process.listeners 'uncaughtException'
                process.removeAllListeners 'uncaughtException'
                process.on 'uncaughtException', (err) ->
                    err.should.eql 'err1'
                    done()
                X.resolver (resolve) ->
                    later -> resolve()
                .onEnd ->
                    throw 'err1'
                .onEnd ->
                    throw 'err2'
            finally
                later -> process.on 'uncaughtException', lst for lst in lsts

        it 'throws when attaching if onEnd runs straight away', ->

            expect(->X().onEnd -> throw 'fail').to.throw 'fail'

        it 'can be chained after then and fail', (done) ->

            c1 = 0
            c2 = 0
            def = X.defer()
            def.promise.then (v) ->
                v.should.eql c1++
            .fail (v) ->
                v.should.eql c2++
            .onEnd done
            later -> def.push 0
            later -> def.pushError 0
            later -> def.push 1
            later -> def.pushError 1
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

        it 'propagates the end', (done) ->

            def = Q.defer()
            c = 0
            p = X(def.promise).map (v) ->
                v
            .forEach().map (a) ->
                a * 2
            p.then (v) ->
                v.should.eql c
                c += 2
            .done()
            p.onEnd done
            later -> def.resolve [0,1,2]

    describe '.endOnError', ->

        it 'stops the stream on first error', (done) ->

            X([0,1,2]).forEach().then((v) -> throw 'fail' if v == 1).endOnError().fail (v) ->
                v.should.eql 'fail'
                done()
            .done()

        it 'returns itself', ->

            x = X()
            x.should.equal x.endOnError()

        it 'stops queued up events', (done) ->

            X([0,1,2]).forEach().serial().then (v) ->
                v.should.not.eql 2
                throw 'fail' if v == 1
                v
            .endOnError()
            .onEnd done

    describe '.all', ->

        it 'waits for all deferreds in an array to be resolved/rejected', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X([def1.promise, def2.promise]).all (arr) ->
                arr.should.eql [41,42]
                done()
            .done()
            later -> def2.resolve 42
            later -> def1.resolve 41

        it 'passes non-deferreds through', (done) ->

            def1 = X.defer()
            X([def1.promise, 42]).all (arr) ->
                arr.should.eql [41,42]
                done()
            .done()
            later -> def1.resolve 41

        it 'passes non-array values through', (done) ->

            X(42).all (arr) ->
                arr.should.eql 42
                done()
            .done()

        it 'inspect object properties and waits for deferreds', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X({a:def1.promise, b:def2.promise}).all (obj) ->
                obj.should.eql {a:41,b:42}
                done()
            .done()
            later -> def2.resolve 42
            later -> def1.resolve 41

        it 'passes non-deferreds props in objects through', (done) ->

            def1 = X.defer()
            X({a:def1.promise, b:42}).all (obj) ->
                obj.should.eql {a:41,b:42}
                done()
            .done()
            later -> def1.resolve 41

        it 'lets objects with no deferred props straight through', (done) ->

            X(a = {a:41, b:42}).all (obj) ->
                obj.should.equal a
                done()
            .done()

        it 'breaks on first error in arrays', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X([def1.promise, def2.promise]).all().fail (v) ->
                v.should.eql 42
                done()
            .done()
            later -> def2.reject 42
            later -> def1.reject 41

        it 'breaks on first error in objects', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X({a:def1.promise, b:def2.promise}).all().fail (v) ->
                v.should.eql 42
                done()
            .done()
            later -> def2.reject 42
            later -> def1.reject 41

        it 'is exposed as X.all', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X.all([def1.promise, def2.promise]).spread (a0, a1) ->
                a0.should.eql 41
                a1.should.eql 42
                done()
            .done()
            later -> def2.resolve 42
            later -> def1.resolve 41

        it 'takes first event value in streams', (done) ->

            def1 = X.defer()
            def2 = X.defer(42)
            X.all([def1.promise, def2.promise]).spread (a0, a1) ->
                a0.should.eql 41
                a1.should.eql 42
                done()
            .done()
            later -> def1.push 41
            later -> def1.push 55

        it 'ignores additional events to already resolved value', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X.all([def1.promise, def2.promise]).spread (a0, a1) ->
                a0.should.eql 41
                a1.should.eql 42
                done()
            .done()
            later -> def1.push 41
            later -> def1.push 55
            later -> def2.push 42

    describe '.snapshot', ->

        it 'takes current event value in streams', (done) ->

            def1 = X.defer()
            def2 = X.defer(42)
            X([def1.promise, def2.promise]).snapshot().spread (a0, a1) ->
                a0.should.eql 41
                a1.should.eql 42
                done()
            .done()
            later -> def1.push 41
            later -> def1.push 55

        it 'is exposed as X.snapshot()', (done) ->

            def1 = X.defer()
            def2 = X.defer(42)
            X.snapshot([def1.promise, def2.promise]).spread (a0, a1) ->
                a0.should.eql 41
                a1.should.eql 42
                done()
            .done()
            later -> def1.push 41
            later -> def1.push 55


        it 'updates to latest event also for already resolved value', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X.snapshot([def1.promise, def2.promise, 44]).spread (a0, a1, a2) ->
                a0.should.eql 55
                a1.should.eql 42
                a2.should.eql 44
                done()
            .done()
            later -> def1.push 41
            later -> def1.push 55
            later -> def2.push 42

        it 'also works for objects', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            X.snapshot({a:def1.promise, b:def2.promise, c:44}).then ({a, b, c}) ->
                a.should.eql 41
                b.should.eql 55
                c.should.eql 44
                done()
            .done()
            later -> def2.push 42
            later -> def2.push 55
            later -> def1.push 41; def1.push 42

    describe '.once', ->

        it 'creates a promise that takes the first value of a stream/promise', (done) ->

            p = X.binder (sink) ->
                later -> sink 42
                later -> sink 43
                later -> sink 44
            .once()

            p.then (v) ->
                v.should.eql 42
                p.isEnded().should.be.true
                p.isFulfilled().should.be.true
                done()
            .done()

        it 'works well with a deep nested', (done) ->

            X.binder (sink) ->
                def1 = X.defer()
                def2 = X.defer()
                later -> def1.push def2.promise
                later -> def2.push 42
                sink def1.promise
            .once (v) ->
                v.should.eql 42
                done()
            .done()

    describe '.serial', ->

        it 'ensures only one argument is executed at a time', ->

            c = 0
            X([0,1,2]).forEach().serial (v) ->
                c++
                def = X.defer()
                later ->
                    def.resolve(v)
                def.promise
            .then (v) ->
                c.should.eql 1
                c--
            .done()

        it 'ensures only one argument is fails at a time', ->

            c = 0
            X([0,1,2]).forEach((v) -> throw v).serial null, (v) ->
                c++
                def = X.defer()
                later ->
                    def.resolve(v)
                def.promise
            .then (v) ->
                c.should.eql 1
                c--
            .done()


    describe 'special promise a+ investigation', ->

        it 'is special', (done) ->

            X().then ->
                then: (ores) ->
                    ores X then: (ires) ->
                        ires(42)
                        throw 'bad'
            .then (v) ->
                done()
            .done()

    describe '.merge', ->

        it 'merges the outputs from several promises/streams', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            c = 0
            X.merge(def1.promise, def2.promise).then (v) ->
                v.should.eql c++
                done() if v == 5
            .done()
            later -> def1.push 0
            later -> def2.push 1
            later -> def1.push 2
            later -> def2.push 3
            later -> def1.push 4
            later -> def2.push 5

        it 'ends the merged when all parts are closed', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            c = 0
            X.merge(def1.promise, def2.promise).then (v) ->
                v.should.eql c++
            .onEnd done
            later -> def1.push 0
            later -> def2.push 1
            later -> def1.end()
            later -> def2.push 2
            later -> def2.end()

        it 'is possible to merge non-deferreds', (done) ->

            c = 0
            X.merge(0,1,2).then (v) ->
                v.should.eql c++
                done() if v == 2
            .done()

        it 'merges also errors', (done) ->

            def1 = X.defer()
            def2 = X.defer()
            c1 = 0
            c2 = 0
            X.merge(def1.promise, def2.promise).then (v) ->
                v.should.eql c1++
                null
            .fail (v) ->
                v.should.eql c2++
                null
            .onEnd done
            later -> def1.push 0
            later -> def2.pushError 0
            later -> def1.pushError 1
            later -> def2.push 1
            later -> def1.pushError 2
            later -> def2.push 2
            later -> def1.end(); def2.end()

    describe '.stop', ->

        it 'immediately stops the stream', (done) ->

            f = null
            stream = X.binder (sink) ->
                t = setInterval (-> sink Date.now()), 1
                return f = spy -> clearInterval t
            stream.then f2 = spy (x) -> x
            stream.onEnd ->
                f.should.have.been.calledOnce
                f2.should.have.been.called
                done()
            later -> stream.stop()
