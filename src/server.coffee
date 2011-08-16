#!/usr/bin/env node
fs              = require('fs')
express         = require('express')
assert          = require('assert')
mime            = require('mime')
http            = require('http')
URL             = require('url')
path            = require('path')
eco             = require('eco')
Browserify      = require('browserify')
BrowserManager  = require('./browser_manager')
DNodeServer     = require('./browser/dnode_server')

# So that developer code can require modules in its own node_modules folder.
require.paths.unshift path.join(process.cwd(), "node_modules")

# Shared server variables.
browsers = new BrowserManager()

# The front-end HTTP server.
httpServer = do ->
    server = express.createServer()
    server.configure () ->
        server.use express.logger()
        server.use Browserify
            mount : '/bootstrap.js',
            require : [
                'dnode'
                path.join(__dirname, 'client', 'dnode_client')
            ]
        server.use express.bodyParser()
        server.use express.cookieParser()
        server.use express.session
            secret: 'change me please'
        server.set 'views', path.join(__dirname, '..', 'views')
        server.set 'view options',
            layout: false

    # Routes
    server.get '/', (req, res) ->
        fs.readdir path.join(process.cwd(), 'html'), (err, files) ->
            throw err if err
            indexPath = path.join(__dirname, '..', 'views', 'index.html.eco')
            fs.readFile indexPath, 'utf8', (err, str) ->
                throw err if err
                tmpl = eco.render str,
                    browsers : browsers.browsers
                    files : files.filter((file) -> /\.html$/.test(file)).sort()
                res.send(tmpl)

    server.get '/browsers/:browserid/index.html', (req, res) ->
        # TODO: permissions checking and making sure browserid exists would
        # go here.
        id = decodeURIComponent(req.params.browserid)
        console.log "Joining: #{id}"
        res.render 'base.jade', browserid : id

    server.get '/browsers/:browserid/*.*', (req, res) ->
        resource = "#{req.params[0]}.#{req.params[1]}"
        resource = resource.replace(/dotdot/g, '..')
        console.log "[bid=#{req.params.browserid}] Proxying request for: #{resource}"
        browsers.find decodeURIComponent(req.params.browserid), (browser) ->
            url = URL.resolve(browser.window.document.URL, resource)
            console.log "Fetching from: #{url}"
            type = mime.lookup(url)
            console.log "MIME type: #{type}"
            theurl = URL.parse(url)
            theurl.search = theurl.search || ""
            theurl.port = theurl.port || 80
            opts =
                host : theurl.hostname
                port : theurl.port
                path : theurl.pathname + theurl.search
            console.log opts
            resreq = http.get opts, (stream) ->
                # Things like HTML, CSS, JS should be sent as text.
                if /^text/.test(type)
                    stream.setEncoding('utf8')
                res.writeHead(200, {'Content-Type' : type})
                stream.on 'data', (data) ->
                    res.write(data)
                stream.on 'end', ->
                    res.end()
            # TODO: After testing, we don't want to throw, we want to log.
            resreq.on 'error', (e) -> throw e

    server.get '/getHTML/:browserid', (req, res) ->
        console.log "browserID: #{req.params.browserid}"
        browsers.find decodeURIComponent(req.params.browserid), (browser) ->
            res.send(browser.window.document.outerHTML)

    server.get '/getText/:browserid', (req, res) ->
        console.log "browserID: #{req.params.browserid}"
        browsers.find decodeURIComponent(req.params.browserid), (browser) ->
            res.contentType('text/plain')
            res.send(browser.window.document.outerHTML)

    server.post '/create', (req, res) ->
        browserInfo = req.body.browser
        id = browserInfo.id
        runscripts = (browserInfo.runscripts? && (browserInfo.runscripts == 'yes'))
        resource = null
        if typeof browserInfo.url != 'string' || browserInfo.url == ''
            resource = "http://localhost:3001/#{browserInfo.localfile}"
        else
            resource = browserInfo.url
        console.log "Creating id=#{id} Loading url= #{resource}"
        try
            browsers.create(id, resource)
            console.log 'BrowserInstance loaded.'
            res.writeHead(301, {'Location' : "/browsers/#{id}/index.html"})
            res.end()
        catch e
            console.log "browsers.create failed"
            console.log e
            console.log e.stack
            send500Error(res)

    send500Error = (res) ->
        res.writeHead 500, {'Content-type': 'text/html'}
        res.end()

    # Start up the front-end server.
    server.listen 3000, () ->
        console.log 'Server listening on port 3000.'

    server

# Create the DNode server
DNodeServer(httpServer, browsers)

# The internal HTTP server used to serve pages to Browser Instances
do ->
    server = express.createServer()

    server.configure () ->
        server.use(express.static(path.join(process.cwd(), 'html')))

    server.listen 3001, ->
        console.log 'Internal HTTP server listening on port 3001 [TODO: remove this].'
