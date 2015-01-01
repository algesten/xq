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
