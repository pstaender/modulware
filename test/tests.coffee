#require('coffee-script/register')
assert = require('assert')

express = require('express')
request = require('request')

Modulware = require('../')

options = {
  basedir: "#{process.cwd()}/test"
  verbosity: 'debug'
}

testOptions = {
  port: 3344
  baseHref: ->
    "http://localhost:#{@port}"
}

createServer = (opts = {}) ->
  {port,app,done} = opts
  port ?= testOptions.port
  unless app
    app = express()
    mw = new Modulware(options, app)
  
  server = app.listen port, ->
    mw.logDebug("Running server instance in port #{server.address().port}")
    done() if typeof done is 'function'

describe 'Init modulware', ->

  it 'expect to init modulware on its own', ->
    assert.equal typeof new Modulware(), 'object'
    assert.equal typeof new Modulware().buildModuleIndex, 'function'
  
  it 'expect to init modulware with expressjs instance', ->
    app = new express()
    assert.equal typeof new Modulware(app).buildModuleIndex, 'function'
    app = new express()
    assert.equal typeof new Modulware({}, app).buildModuleIndex, 'function'
    app = new express()
    assert.equal typeof new Modulware({}).applyOnExpress(app), 'function'

describe 'indexing modules', ->

  it 'expect to find all valid modules', ->
    app = new express()
    mw = new Modulware(options, app)
    assert.equal Object.keys(mw.modules).length, 3
    assert.equal Object.keys(mw.modules).sort().join(','), 'module,other-module,second-module'

  it 'expect to have valid routes and methods for modules', ->
    app = new express()
    mw = new Modulware(options, app)

  it 'expect to start a server with module depending routes', (done) ->
    createServer(
      done: ->
        id = 5
        request.get "#{testOptions.baseHref()}/contact/#{id}", (err, res) ->
          assert.equal(err, null)
          assert.equal(res.statusCode, 200)
          assert.equal(res.body, '{"name":"Contact #'+id+'","id":"'+id+'"}')
          request.get "#{testOptions.baseHref()}/test", (err, res) ->
            assert.equal(err, null)
            assert.equal(res.statusCode, 200)
            assert.equal(res.body, ':)')
            done()
    )