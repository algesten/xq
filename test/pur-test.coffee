chai   = require 'chai'
expect = chai.expect
chai.should()
chai.use(require 'sinon-chai')
{ assert, spy, match, mock, stub } = require 'sinon'

Pur = require '../src/pur'

later = (f) -> setTimeout f, 1

describe 'Pur', ->

    describe 'value instantiation', ->

        it 'is done Pur(x)', ->

            px = Pur(x = 42)
            px.isEnded().should.be.true

        it 'is also ok with nothing', (done) ->

            px = Pur()
            px.isEnded().should.be.true
            px.then done

        it 'nested 2 levels are fine', (done) ->

            px = Pur(Pur(42))
            px.isEnded().should.be.true
            px.then (v) ->
                v.should.eql 42
                done()
            .done()

        it 'nested 3 levels are fine', (done) ->

            px = Pur(Pur(Pur(42)))
            px.isEnded().should.be.true
            px.then (v) ->
                v.should.eql 42
                done()
            .done()

    describe 'error instantiation', ->

        it 'is done Pur.reject(e)', ->

            pe = Pur.reject(e = new Error('wrong'))
            pe.isEnded().should.be.true

        it 'is ok with nothing', (done) ->

            pe = Pur.reject()
            pe.isEnded().should.be.true
            pe.fail done

    describe 'defer instantiation', ->

        it 'is done Pur.defer()', ->

            def = Pur.defer()
            def.should.be.instanceof Pur.Defer

        it 'can optionally take an initial value', ->

            def = Pur.defer(x = 42)
            def.should.be.instanceof Pur.Defer

    describe 'def.pur', ->

        it 'is used to get Pur from def', ->

            def = Pur.defer()
            expect(def.pur).to.be.instanceof Pur
            def.pur._defer.should.equal def

        it 'should not be ended', ->

            def = Pur.defer()
            def.pur.isEnded().should.eql false

    describe 'errors', ->

        it 'are silently consumed unless chain is .done', ->

            expect(-> Pur.reject('fail')).to.not.throw 'fail'
            expect(-> Pur.reject('fail').done()).to.throw 'fail'

        it 'can also be made known by using Pur.bubble()', ->

            expect(-> Pur(42).then (v) -> Pur.bubble('fail')).to.throw 'fail'

        it 'is different for defers with later done', ->

            def = Pur.defer()
            expect(->def.reject('fail')).to.not.throw 'fail'
            expect(->def.pur.done()).to.throw 'fail'

        it 'is different for defers with done then rejected', ->

            def = Pur.defer()
            expect(->def.pur.done()).to.not.throw 'fail'
            expect(->def.reject('fail')).to.throw 'fail'

    describe '.then', ->

        it 'handles simple values', (done) ->

            Pur(42).then (v) ->
                v.should.eql 42
                done()

        it 'handles deferred', (done) ->

            def = Pur.defer()
            def.pur.then (v) ->
                v.should.eql 42
                done()
            def.push 42

        it 'handles then connected after deferred push', (done) ->

            def = Pur.defer()
            def.push 42
            def.pur.then (v) ->
                v.should.eql 42
                done()

        it 'handles then connected after deferred resolve', (done) ->

            def = Pur.defer()
            def.resolve 42
            def.pur.then (v) ->
                v.should.eql 42
                done()

        it 'handles deferred in deferreds', (done) ->

            def = Pur.defer()
            def.pur.then (v) ->
                v.should.eql 42
                done()
            def2 = Pur.defer()
            def.push def2.pur
            def2.push 42

        it 'handles deferred in deferreds in deferreds', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.then (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            def2 = Pur.defer()
            def3 = Pur.defer()
            def2.push def3.pur
            def.push def2.pur
            def3.push 42
            def3.push 43

        it 'handles deferred in deferreds in deferreds created on the fly', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.then (v) ->
                v.should.eql 142 + n++
                done() if n == 2
            .done()
            def2 = Pur.defer()
            def3 = Pur.defer()
            def2.push def3.pur
            def.push def3.pur.then (v) ->
                defnew = Pur.defer()
                later -> defnew.resolve v + 100
                defnew.pur
            .done()
            def3.push 42
            def3.push 43

        it 'handles deferred in fails in deferreds created on the fly', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.fail (v) ->
                v.should.eql 142 + n++
                done() if n == 2
            .done()
            def2 = Pur.defer()
            def3 = Pur.defer()
            def2.push def3.pur
            def.push def3.pur.then (v) ->
                defnew = Pur.defer()
                later -> defnew.reject v + 100
                defnew.pur
            .done()
            def3.push 42
            def3.push 43

        it 'resolves pushed deferreds', (done) ->

            def = Pur.defer()
            def.pur.then (v) ->
                v.should.eql 42
                done()
            .done()
            def.push Pur(42)

        it 'resolves already pushed value', (done) ->

            def = Pur.defer()
            def.push 42
            def.pur.then (v) ->
                v.should.eql 42
                done()

        it 'handles simple transforming chains', (done) ->

            Pur(42).then (v) ->
                v.should.eql 42
                panda:true
            .then (v) ->
                v.should.eql panda:true
                done()

        it 'handles transforming chains with deferred', (done) ->

            Pur(42).then (v) ->
                v.should.eql 42
                Pur(panda:true)
            .then (v) ->
                v.should.eql panda:true
                done()

        it 'handles transforming chains with later deferred', (done) ->

            Pur(42).then (v) ->
                v.should.eql 42
                def = Pur.defer()
                later -> def.resolve panda:true
                def.pur
            .then (v) ->
                v.should.eql panda:true
                panda:42
            .then (v) ->
                v.should.eql panda:42
                done()

        it 'can do transforming chains with root deferred', (done) ->

            def = Pur.defer()
            def.pur.then (v) ->
                v.should.eql 42
                panda:42
            .then (v) ->
                v.should.eql panda:42
                done()
            later -> def.resolve 42

        it 'can handle repeated events through chain', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.then (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            def.push 42
            def.push 43

        it 'does not get repeated events when def is ended', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.then (v) ->
                v.should.eql 42
                done()
            def.push 42
            def.end()
            def.push 43

        it 'will not get event for resolved', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.then (v) ->
                v.should.eql 42
                done()
            def.resolve(42)
            def.push 43

        it 'can be bound with arguments', (done) ->

            Pur(42).then 1, 2, (a0, a1, a2) ->
                a0.should.eql 1
                a1.should.eql 2
                a2.should.eql 42
                done()
            .done()

        it 'can be bound with arguments and still receive an array', (done) ->

            Pur([42]).then 1, 2, (a0, a1, a2) ->
                a0.should.eql 1
                a1.should.eql 2
                a2.should.eql [42]
                done()
            .done()

it 'is aliased to map', ->

            Pur::then.should.equal Pur::map

    describe '.fail', ->

        it 'is invoked for simple rejected', (done) ->

            Pur.reject(42).fail (v) ->
                v.should.eql 42
                done()

        it 'is not invoked for non rejected', (done) ->

            Pur(42).then (v) ->
                v.should.eql 42
                done()
            .fail (v) ->
                done('bad')

        it 'is invoked if chained after .then', (done) ->

            Pur.reject(42).then ->
                done('bad')
            .fail (v) ->
                v.should.eql 42
                done()

        it 'invokes following then if no error', (done) ->

            Pur.reject(42).fail (v) ->
                v
            .then (v) ->
                v.should.eql 42
                done()

        it 'doesnt invoke any following fail if no error', (done) ->

            Pur.reject(42).fail (v) ->
                v
            .fail (v) ->
                done('bad')
            .then (v) ->
                v.should.eql 42
                done()

        it 'invokes fail for errors thrown in then', (done) ->

            Pur(42).then (v) ->
                throw 'failed'
            .then (v) ->
                done('bad')
            .fail (err) ->
                err.should.eql 'failed'
                done()

        it 'can handle repeated errors through chain', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.fail (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            def.pushError 42
            def.pushError 43

        it 'does not get repeated errors when def is ended', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.fail (v) ->
                v.should.eql 42
                done()
            def.pushError 42
            def.end()
            def.pushError 43

        it 'will not get errors for resolved', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.fail (v) ->
                v.should.eql 42
                done()
            def.reject(42)
            def.pushError 43

        it 'can be bound with arguments', (done) ->

            Pur.reject(42).fail 1, 2, (a0, a1, a2) ->
                a0.should.eql 1
                a1.should.eql 2
                a2.should.eql 42
                done()
            .done()

        it 'is aliased to catch', ->

            Pur::fail.should.equal Pur::catch

    describe '.always', ->

        it 'is invoked for normal values', (done) ->

            Pur(42).always (v, isError) ->
                v.should.eql 42
                isError.should.be.false
                done()
            .done()

        it 'is invoked for errors', (done) ->

            Pur.reject(42).always (v, isError) ->
                v.should.eql 42
                isError.should.be.true
                done()
            .done()

        it 'becomes normal values after in chain', (done) ->

            Pur.reject(42).always (v) ->
                v.should.eql 42
                v
            .fail ->
                done('bad')
            .then (v) ->
                v.should.eql 42
                done()

        it 'can be event fed both values and errors', (done) ->

            def = Pur.defer()
            n = 0
            def.pur.always (v) ->
                v.should.eql 42 + n++
                done() if n == 2
            .done()
            def.pushError 42
            def.push 43

        it 'can be bound with arguments when value', (done) ->

            Pur(42).always 1, 2, (a0, a1, a2) ->
                a0.should.eql 1
                a1.should.eql 2
                a2.should.eql 42
                done()
            .done()

        it 'can be bound with arguments when error', (done) ->

            Pur.reject(42).always 1, 2, (a0, a1, a2) ->
                a0.should.eql 1
                a1.should.eql 2
                a2.should.eql 42
                done()
            .done()

        it 'is aliased to fin and finally', ->

            Pur::always.should.equal Pur::fin
            Pur::always.should.equal Pur::finally

    describe '.spread', ->

        it 'unpacks any incoming array to function arguments', (done) ->

            Pur([1,2]).spread (a0, a1) ->
                a0.should.eql 1
                a1.should.eql 2
                done()
            .done()

        it 'handles single values', (done) ->

            Pur(42).spread (a0, a1) ->
                a0.should.eql 42
                expect(a1).to.be.undefined
                done()
            .done()

        it 'can be bound for single values', (done) ->

            Pur(42).spread 1, (a0, a1) ->
                a0.should.eql 1
                a1.should.eql 42
                done()
            .done()

        it 'can be bound for arrays', (done) ->

            Pur([42,43]).spread 1, (a0, a1, a2) ->
                a0.should.eql 1
                a1.should.eql 42
                a2.should.eql 43
                done()
            .done()
