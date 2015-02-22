X = require '../src/xq'
mocha = require 'mocha'

adapter = {
    resolved: X
    rejected: X.reject
    deferred: -> X.defer()
}

describe 'Promises/A+ Tests', ->
    require('promises-aplus-tests').mocha adapter
