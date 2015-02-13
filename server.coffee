# !./node_modules/coffee-script/bin/coffee %

util = require 'util'
async = require 'async'
http = require 'http'
csv = require 'csv'
fs = require 'fs'
url = require 'url'
pubres = require 'pubres'
jade = require 'jade'
{ MongoClient } = require 'mongodb'


mapping = {}
index = ''
jadeDoiInfo = jade.compileFile('templates/doi.jade')
links = null
file_links = null

init = ->
    file_links = fs.readFileSync("infolis-links.csv")
    index = fs.readFileSync("index.html")
    links = csv.parse(delimiter: "|")
    cur = 0
    links.on "readable", ->
        while record = links.read()
            cur += 1
            id_a = record[1]
            id_b = record[5]
            [[id_a, id_b], [id_b, id_a]].forEach (pair) ->
                if pair[0] of mapping
                    mapping[pair[0]].push pair[1]
                else
                    mapping[pair[0]] = [pair[1]]
            console.log("Loading link #"+cur) if cur % 5000 is 0
    links.write file_links
    links.end()

sendError = (res, msg) ->
    res.writeHead 400, "Content-Type": "application/problem+json"
    res.end msg
    return res

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
    ct_default = "application/json"
    if acc is null
        return ct_default
    if acc is "*/*"
        return "text/html"
    else
        return acc.substring(0, acc.indexOf(','))

handle_ids_for_id = (req, res) ->
    url_parts = url.parse(req.url, true)
    needle = url_parts.query.id
    console.log needle
    matches_raw = mapping[needle] or []
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


console.log "Loading links"
init()
console.log "Starting server"

handle_default = (req, res) ->
    # just for debugging
    index = fs.readFileSync("index.html")
    res.writeHead 200, "Content-Type": "text/html"
    res.end index

handle_doi_info = (req, res, db) ->
    ret = {}
    needle = url.parse(req.url, true).query.doi
    collection = db.collection('doi_info')
   
    sendResults = (req, res, results) ->
        # if _content_type_from_headers(req.headers) is "text/html"
        #     res.writeHead 200, "Content-Type": "text/html"
        #     res.end jadeDoiInfo({data: results})
        # else
            res.writeHead 200, "Content-Type": "application/json"
            res.end JSON.stringify(results)

    # A trailing slash is most probably an error
    needle = needle.replace(/\/$/, '')

    mongoId = needle.replace(/[^a-zA-Z0-9]/g, "_")
    console.log "Searching for #{needle}, stored as #{mongoId} in db.doi_info"
    collection.findOne {_id: mongoId}, (mongoErr, mongoResult) ->
        if mongoErr
            return sendError(res, mongoErr)
        # TODO don't cache for testing
        if mongoResult
            return sendResults(req, res, mongoResult)
        crossRef = pubres.CrossRef()
        zotero = pubres.Zotero()
        googleSearch = pubres.GoogleSearch({ resultsPerPage: 1 })
        async.waterfall [
            (callback) ->
                # console.log "STEP 1"
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
           #      console.log "STEP 2"
           #      call
                # if previousStepResults.crossRefWorks and not previousStepResults.crossRefWorks.attachments and previousStepResults.crossRefWorks.title
                #     googleSearch.searchPDF previousStepResults.crossRefWorks.title, (err, googleResult) ->
                #         callback null, util._extend(previousStepResults, {googleSearch:googleResult})
        ], (err, results) ->
            # if err
            #     return sendError(res, "" + JSON.stringify(err)) if err
            boilerplate = 
                _id: mongoId
                doi: needle
                updated: new Date().toISOString()
            results = util._extend(boilerplate, results)
            collection.save results, (mongoErr, mongoResult) ->
                return sendError(res, ""+ mongoErr) if mongoErr
                return sendResults(req, res, results)

MongoClient.connect('mongodb://localhost:27017/infolis', (mongoErr, db) ->
    if (mongoErr)
        console.log "Couldn't connect to MongoDB"
        console.log mongoErr
        return
    http.createServer((req, res) ->
        res.setHeader "Access-Control-Allow-Origin", "*"
        res.setHeader "Access-Control-Allow-Headers", "X-Requested-With, exlrequesttype"

        action = url.parse(req.url, true).pathname.split('/').pop()
        if action is "ids-for-id"
            handle_ids_for_id(req, res, db)
        else if action is "doi-info"
            handle_doi_info(req, res, db)
        else
            handle_default(req, res, db)
    ).listen 3000)
