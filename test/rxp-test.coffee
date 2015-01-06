chai   = require 'chai'
expect = chai.expect
chai.should()
chai.use(require 'sinon-chai')
{ assert, spy, match, mock, stub, sandbox } = require 'sinon'

RxP = require '../src/rxp'

later = (f) -> setTimeout f, 5

describe 'RxP', ->

    describe 'value instantiation', ->

        it 'is done RxP(x)', ->

            px = RxP(x = 42)
            px.isEnded().should.eql true

        it 'is also ok with nothing', (done) ->

            px = RxP()
            px.isEnded().should.eql true
            px.then done

        it 'nested 2 levels are fine', (done) ->

            px = RxP(RxP(42))
            px.isEnded().should.eql true
            px.then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'nested 3 levels are fine', (done) ->

            px = RxP(RxP(RxP(42)))
            px.isEnded().should.eql true
            px.then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'nested deferred is interesting', (done) ->

            def = RxP.defer()
            px = RxP(def.promise)
            c = 42
            px.then (v) ->
                v.should.eql c++
                done() if v == 43
            .done()
            later -> def.push 42
            later -> def.push 43

    describe 'error instantiation', ->

        it 'is done RxP.reject(e)', ->

            pe = RxP.reject(e = new Error('wrong'))
            pe.isEnded().should.eql true

        it 'is ok with nothing', (done) ->

            pe = RxP.reject()
            pe.isEnded().should.eql true
            pe.fail done

    describe 'defer instantiation', ->

        it 'is done RxP.defer()', ->

            def = RxP.defer()

        it 'can optionally take an initial value', ->

            def = RxP.defer(x = 42)

    describe 'def.promise', ->

        it 'is used to get RxP from def', ->

            def = RxP.defer()
            expect(def.promise).to.be.instanceof RxP
            def.promise._def.should.equal def

        it 'should not be ended', ->

            def = RxP.defer()
            def.promise.isEnded().should.eql false

    describe 'errors', ->

        it 'are silently consumed', ->

            RxP.reject(42)
            null

        it 'stops the chain with done', ->

            expect(RxP(42).done()).to.be.undefined

        it 'are reported if .done', (done) ->

            RxP.reject(e = new Error('fail')).done (->), (v) ->
                v.should.equal e
                done()

        it 'is different for defers with later done', (done) ->

            def = RxP.defer()
            def.reject('fail')
            def.promise.done (->), (v) ->
                v.should.eql 'fail'
                done()

        it 'is different for defers with done then rejected', (done) ->

            def = RxP.defer()
            def.promise.done (->), (v) ->
                v.should.eql 'fail'
                done()
            def.reject('fail')

    describe '.then', ->

        it 'handles simple values', (done) ->

            RxP(42).then (v) ->
                v.should.eql 42
                done()

        it 'handles deferred', (done) ->

            def = RxP.defer()
            def.promise.then (v) ->
                v.should.eql 42
                done()
            def.push 42

        it 'handles then connected after deferred push', (done) ->

            def = RxP.defer()
            def.push 42
            def.promise.then (v) ->
                v.should.eql 42
                done()

        it 'handles then connected after deferred resolve', (done) ->

            def = RxP.defer()
            def.resolve 42
            def.promise.then (v) ->
                v.should.eql 42
                done()

        it 'resolves pushed deferreds', (done) ->

            def = RxP.defer()
            def.promise.then (v) ->
                v.should.eql 42
                done()
            .done()
            def.push RxP(42)

        it 'resolves already pushed value', (done) ->

            def = RxP.defer()
            def.push 42
            def.promise.then (v) ->
                v.should.eql 42
                done()

        it 'handles simple transforming chains', (done) ->

            RxP(42).then (v) ->
                v.should.eql 42
                panda:true
            .then (v) ->
                v.should.eql panda:true
                done()

        it 'is ok to unwrap deferreds', (done) ->

            RxP().then ->
                RxP(panda:true)
            .done(->done())

        it 'handles transforming chains with deferred', (done) ->

            RxP(42).then (v) ->
                v.should.eql 42
                RxP(panda:true)
            .then (v) ->
                v.should.eql panda:true
                done()
            .done()

        it 'handles transforming chains with later deferred', (done) ->

            RxP(42).then (v) ->
                v.should.eql 42
                def = RxP.defer()
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

            def = RxP.defer()
            def.promise.then (v) ->
                v.should.eql 42
                panda:42
            .then (v) ->
                v.should.eql panda:42
                done()
            later -> def.resolve 42

        it 'can handle repeated events through chain', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            .done()
            def.push 42
            def.push 43

        it 'does not get repeated events when def is ended', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42
                done()
            def.push 42
            def.end()
            def.push 43

        it 'will not get event for resolved', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42
                done()
            def.resolve(42)
            def.push 43

        it 'takes two functions', (done) ->

            def = RxP.defer()
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

            def = RxP.defer()
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

            def = RxP.defer()
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

            RxP::then.should.equal RxP::map


    describe '.then with defered in defereds', ->

        it 'is ok', (done) ->

            def = RxP.defer()
            def.promise.then (v) ->
                v.should.eql 42
                done()
            .done()
            def2 = RxP.defer()
            def.push def2.promise
            def2.push 42

        it 'handles deferreds in deferreds', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            .done()
            def2 = RxP.defer()
            def3 = RxP.defer()
            def2.push def3.promise
            def.push def2.promise
            later -> def3.push 42
            later -> def3.push 43

        it 'handles deferreds created on the fly', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.then (v) ->
                v.should.eql 142 + n++
                done() if n == 2
            .done()
            def2 = RxP.defer()
            def3 = RxP.defer()
            def2.push def3.promise
            def.push def3.promise.then (v) ->
                defnew = RxP.defer()
                later -> defnew.resolve v + 100
                defnew.promise
            later -> def3.push 42
            later -> def3.push 43

        it 'handles failed deferreds created on the fly', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 142 + n++
                done() if n == 2
            .done()
            def2 = RxP.defer()
            def3 = RxP.defer()
            def2.push def3.promise
            def.pushError def3.promise.then (v) ->
                defnew = RxP.defer()
                later -> defnew.reject v + 100
                defnew.promise
            later -> def3.push 42
            later -> def3.push 43

    describe '.fail', ->

        it 'is invoked for simple rejected', (done) ->

            RxP.reject(42).fail (v) ->
                v.should.eql 42
                done()

        it 'is not invoked for non rejected', (done) ->

            RxP(42).then (v) ->
                v.should.eql 42
                done()
            .fail (v) ->
                done('bad')

        it 'is invoked if chained after .then', (done) ->

            RxP.reject(42).then ->
                done('bad')
            .fail (v) ->
                v.should.eql 42
                done()

        it 'invokes following then if no error', (done) ->

            RxP.reject(42).fail (v) ->
                v
            .then (v) ->
                v.should.eql 42
                done()

        it 'doesnt invoke any following fail if no error', (done) ->

            RxP.reject(42).fail (v) ->
                v
            .fail (v) ->
                done('bad')
            .then (v) ->
                v.should.eql 42
                done()

        it 'invokes fail for errors thrown in then', (done) ->

            RxP(42).then (v) ->
                throw 'failed'
            .then (v) ->
                done('bad')
            .fail (err) ->
                err.should.eql 'failed'
                done()

        it 'can handle repeated errors through chain', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            def.pushError 42
            def.pushError 43

        it 'does not get repeated errors when def is ended', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 42
                done()
            def.pushError 42
            def.end()
            def.pushError 43

        it 'will not get errors for resolved', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.fail (v) ->
                v.should.eql 42
                done()
            def.reject(42)
            def.pushError 43

        it 'is aliased to catch', ->

            RxP::fail.should.equal RxP::catch

    describe '.always', ->

        it 'is invoked for normal values', (done) ->

            RxP(42).always (v, isError) ->
                v.should.eql 42
                isError.should.eql false
                done()
            .done()

        it 'is invoked for errors', (done) ->

            RxP.reject(42).always (v, isError) ->
                v.should.eql 42
                isError.should.eql true
                done()
            .done()

        it 'becomes normal values after in chain', (done) ->

            RxP.reject(42).always (v) ->
                v.should.eql 42
                v
            .fail ->
                done('bad')
            .then (v) ->
                v.should.eql 42
                done()

        it 'can be event fed both values and errors', (done) ->

            def = RxP.defer()
            n = 0
            def.promise.always (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            .done()
            def.pushError 42
            def.push 43

        it 'is aliased to fin and finally', ->

            RxP::always.should.equal RxP::fin
            RxP::always.should.equal RxP::finally

    describe '.spread', ->

        it 'unpacks any incoming array to function arguments', (done) ->

            RxP([1,2]).spread (a0, a1) ->
                a0.should.eql 1
                a1.should.eql 2
                done()
            .done()

        it 'handles single values', (done) ->

            RxP(42).spread (a0, a1) ->
                a0.should.eql 42
                expect(a1).to.be.undefined
                done()
            .done()

    describe '.forEach', ->

        it 'turns any incoming array into a series of events', (done) ->

            c = 0
            RxP([0,1,2,3,4,5]).forEach (v) ->
                v.should.eql c++
                done() if v == 5
            .done()

        it 'does nothing with an empty array', (done) ->

            RxP([]).forEach (v) ->
                done('bad ' + v)
            .done()
            done()

        it 'passes non arrays down the chain', (done) ->

            RxP(42).forEach (v) ->
                v.should.eql 42
                done()
            .done()

        it 'no handler is fine', (done) ->

            c = 0
            RxP([0,1,2,3]).forEach().then (v) ->
                v.should.eql c++
                done() if v == 3
            .done()

    describe '.[step].serial', ->

        it 'has a serial version of .forEach', (done) ->

            def = RxP.defer()
            c = 0
            RxP([0,def.promise,2]).forEach.serial().then (v) ->
                v.should.eql c++
                done() if v == 2
            .done()
            later -> def.resolve(1)
            null

        it 'has a serial version of .then', (done) ->

            def = null
            c = 0
            RxP([0,1,2]).forEach().then.serial f = spy (v) ->
                if v == 1
                    (def = RxP.defer()).promise
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
            RxP([0,1,2]).forEach (v) ->
                throw v
            .fail.serial f = spy (v) ->
                if v == 1
                    (def = RxP.defer()).promise
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
            later -> def.resolve(4)
            null

        it 'has a serial version of .always', (done) ->

            def = null
            c = 0
            RxP([0,1,2]).forEach (v) ->
                if v == 1
                    throw v
                else
                    v
            .always.serial f = spy (v) ->
                if v == 1
                    (def = RxP.defer()).promise
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
            later -> def.resolve(4)
            null

        it 'has a serial version of .spread', (done) ->

            def = null
            c = 0
            RxP([0,1,2]).forEach (v) ->
                [v,v]
            .spread.serial f = spy (v1, v2) ->
                v1.should.eql v2
                if v1 == 1
                    (def = RxP.defer()).promise
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
            later -> def.resolve(4)
            null

    describe '.onEnd', ->

        it 'is called when stream ends for promises', (done) ->

            RxP().onEnd -> done()

        it 'is called for deferred promise', (done) ->

            (def = RxP.defer()).promise.onEnd -> done()
            later -> def.resolve 1

        it 'waits until end of stream', (done) ->

            (def = RxP.defer()).promise.onEnd f = spy -> done()
            later -> def.push 0
            later -> def.push 1
            later -> def.push 2
            later -> f.should.not.have.been.calledOnce
            later -> def.end()
