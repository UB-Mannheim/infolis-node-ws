# !./node_modules/coffee-script/bin/coffee %

# logging
log = require('./logging').defaultLogger

_extend = require('util')._extend
async = require 'async'
csv = require 'csv'
fs = require 'fs'
url = require 'url'
pubres = require './lib/pubres'
jade = require 'jade'
{ MongoClient } = require 'mongodb'

doi2urnMapping = {}

readCsvLinks = ->
    return
    file_links = null
    file_links = fs.readFileSync("infolis-links.csv")
    links = csv.parse(delimiter: "|")
    cur = 0
    links = null
    links.on "readable", ->
        while record = links.read()
            cur += 1
            id_a = record[1]
            id_b = record[5]
            [[id_a, id_b], [id_b, id_a]].forEach (pair) ->
                if pair[0] of doi2urnMapping
                    doi2urnMapping[pair[0]].push pair[1]
                else
                    doi2urnMapping[pair[0]] = [pair[1]]
            # log.info("Loading link #"+cur) if cur % 5000 is 0
    links.write file_links
    links.end()

_matches_to_objects = (matches) ->
    ret = []
    for id in matches
        ret.push {
            "@type": "MatchResult",
            "accuracy": Math.random(),
            "id": id
        }
    ret

_content_type_from_headers = (headers) ->
    acc = headers.accept
    if acc.indexOf(',')  > -1
        acc = acc.substring 0, acc.indexOf(',')
    ct_default = "application/json"
    if acc is null
        return ct_default
    if acc is "*/*"
        return "text/html"
    else
        return acc

_findPdfLink = (doc) ->
    if doc.zotero
        for att in doc.zotero[0].attachments
            if att.mimeType is 'application/pdf'
                return att.url
    return "---"

handle_ids_for_id = (req, res) ->
    url_parts = url.parse(req.url, true)
    needle = url_parts.query.id
    # log.info needle
    matches_raw = doi2urnMapping[needle] or []
    if matches_raw.length > 0
        res.writeHead 200, "Content-Type": "application/json"
    else
        res.writeHead 404, "Content-Type": "application/json"
    ret = {
        "@context": {
            "needle": {
                "@id": "http://onto.dm2e.eu/omnom/parameterValue",
                "@type": "@id"
            },
            "accuracy": {
                "@id": "http://rs.tdwg.org/dwc/terms/measurementAccuracy",
                "@type": "http://www.w3.org/2001/XMLSchema#float",
            },
            "id": {
                "@id": "http://foo.bar/id",
                "@type": "@id"
            }
        },
        "@id": req.url,
        "@type": "MatchResultList",
        "needle": needle,
        "skos:broadMatch": _matches_to_objects matches_raw
    }
    res.end JSON.stringify(ret)


handle_default = (req, res, next) ->
    res.render 'index'

handle_doi_info = (req, res, next) ->
    db = req.mongoDB
    needle = req.query.doi
    if not needle
        return next(message : "Missing 'doi' parameter.")

    # A trailing slash is most probably an error
    needle = needle.replace(/\/$/, '')
    # Use the DOI as _id in Mongo, replace all non-alnum chars with _
    mongoId = needle.replace(/[^a-zA-Z0-9]/g, "_")
    # collection to write to
    collection = db.collection('doi_info')

    # Send the result to the client using conneg
    sendResults = (doc) ->
        res.status 200
        res.format
            default: () ->
                res.json doc
            html: () ->
                res.status 303
                res.render 'debug-output', data: doc
            "application/pdf": () ->
                res.location(_findPdfLink(doc))
                res.end()

    # log.info "Searching for #{needle}, stored as #{mongoId} in db.doi_info"
    collection.findOne {_id: mongoId}, (mongoErr, mongoResult) ->
        if mongoErr
            return next(mongoErr)
        # TODO don't cache for testing
        if mongoResult and not req.query.force
            return sendResults(mongoResult)
        crossRef = pubres.CrossRef()
        zotero = pubres.Zotero()
        googleSearch = pubres.GoogleSearch({ resultsPerPage: 1 })
        async.waterfall [
            (callback) ->
                # log.info "STEP 1"
                async.parallel {
                    # # Ask for the agency
                    # crossRefAgency: (callback) -> crossRef.getAgencyForDOI needle, callback
                    # # Ask for metadata
                    crossRefWorks: (callback) -> crossRef.getBibliographicMetadataForDOI needle, callback
                    # # Resolve the DOI and query Zotero web service for more information on this
                    zotero: (callback) -> zotero.scrapeDOI needle, callback
                }, (err, thisStepResults) ->
                    # callback err, thisStepResults
                    callback null, thisStepResults
           # (previousStepResults, callback) ->
           #      log.info "STEP 2"
           #      call
                # if previousStepResults.crossRefWorks and not previousStepResults.crossRefWorks.attachments and previousStepResults.crossRefWorks.title
                #     googleSearch.searchPDF previousStepResults.crossRefWorks.title, (err, googleResult) ->
                #         callback null, _extend(previousStepResults, {googleSearch:googleResult})
        ], (err, results) ->
            # if err
            #     return sendError(res, "" + JSON.stringify(err)) if err
            boilerplate = 
                _id: mongoId
                doi: needle
                updated: new Date().toISOString()
            results = _extend(boilerplate, results)
            collection.save results, (mongoErr, mongoResult) ->
                return sendError(res, ""+ mongoErr) if mongoErr
                res.json(results)

startServer = (db) ->
    express = require 'express'
    app = express()

    # Templates
    app.set 'views', './views'
    app.set 'view engine', 'jade'

    # Inject reference to MongoDB middleware
    app.use (req, res, next) ->
        req.mongoDB = db
        next()
    # CORS middleware
    app.use (req, res, next) ->
        res.header 'Access-Control-Allow-Origin', '*'
        res.header 'Access-Control-Allow-Headers', 'Content-Type, X-Requested-With, exlrequesttype'
        next()

    ###
    # set up routes
    # NOTE: Must be defined before error handling middleware but after data-injection middleware
    ###
    app.get '/ids-for-id', handle_ids_for_id
    app.get '/doi-info', handle_doi_info
    app.get '/', handle_default

    # Error handler
    app.use (err, req, res, next) ->
        res.status 400
        res.format
            'application/json': () ->
                res.set "Content-Type": "application/problem+json"
                res.json err
            'text/html': () ->
                res.set "Content-Type": "text/html"
                res.render 'error', message: err.message
            'default': () ->
                res.set "Content-Type": "text/plain"
                res.set "X-Error-Message": err.message
                res.end()

    # Run the server
    http = require 'http'
    server = http.createServer app
    server.listen 3000

MongoClient.connect 'mongodb://localhost:27017/infolis', (mongoErr, db) ->
    log.info "Loading links"
    readCsvLinks()
    log.info "Starting server"
    if (mongoErr)
        log.info "Couldn't connect to MongoDB"
        log.info mongoErr
        return
    startServer(db)

