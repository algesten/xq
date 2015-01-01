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

    describe 'error instantiation', ->

        it 'is done Pur.reject(e)', ->

            pe = Pur.reject(e = new Error('wrong'))
            pe.isEnded().should.be.true

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

        it 'resolves already pushed value', (done) ->

            def = Pur.defer()
            def.push 42
            def.pur.then (v) ->
                v.should.eql 42
                done()

        it 'handles simple transformative chains', (done) ->

            Pur(42).then (v) ->
                v.should.eql 42
                panda:true
            .then (v) ->
                v.should.eql panda:true
                done()

        it 'handles transformative chains with deferred', (done) ->

            Pur(42).then (v) ->
                v.should.eql 42
                Pur(panda:true)
            .then (v) ->
                v.should.eql panda:true
                done()

        it 'handles transformative chains with later deferred', (done) ->

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

        it 'can do transformative chains with root deferred', (done) ->

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

    describe '.always', ->

        it 'is invoked for normal values', (done) ->

            Pur(42).always (v) ->
                v.should.eql 42
                done()

        it 'is invoked for errors', (done) ->

            Pur.reject(42).always (v) ->
                v.should.eql 42
                done()
