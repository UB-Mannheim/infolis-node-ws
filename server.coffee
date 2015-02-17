# logging
log = require('./lib/logging').defaultLogger
pubres = require './lib/pubres'
NS = require './lib/namespaces'
RdfUtil = require('./lib/rdfUtil')

Yaml = require 'js-yaml'
N3 = require 'n3'
jsonld = require 'jsonld'


_extend = require('util')._extend
async = require 'async'
csv = require 'csv'
fs = require 'fs'
url = require 'url'
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
  return ""

handle_ids_for_id = (req, res) ->
  needle = req.query.id
  if not needle
    return next(message : "Missing 'id' parameter.")
  matches_raw = doi2urnMapping[needle] or []
  res.status = if matches_raw.length > 0 then 200 else 404
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
  res.json ret

handle_context = (req, res, next) ->
  # namespaces
  context = NS.toJSONLD()
  return json.send context

handle_vocab_gesis = (req, res, next) ->
  try
    gesisContext = Yaml.safeLoad(fs.readFileSync('./views/gesis-context.ld.yaml', 'utf8'))
  catch e
      return next {status: 500, message: "Couldn't load ontology", body: e}
  context = NS.toJSONLD()
  joinedContext = _extend(context, gesisContext)
  res.status 200
  res.set "Content-Type": "application/ld+json"
  res.json joinedContext

handle_vocab = (req, res, next) ->
  # the vocabulary
  # rawVocab = CSON.load './views/infolis-vocabulary.csonld'
  try
    rawVocab = Yaml.safeLoad(fs.readFileSync('./views/infolis-vocabulary.ld.yaml', 'utf8'))
  catch e
      return next {status: 500, message: "Couldn't load ontology", body: e}
  # namespaces
  context = NS.toJSONLD()
  # JSON-LD presentation mode
  profile = req.query.jsonld_profile || 'compact'

  if req.params.term
    [ filteredVocab ] = rawVocab['@graph'].filter (doc) ->
      doc['@id'] is 'infolis:' + req.params.term or
      doc['@id'] is NS.infolis + req.params.term
    if not filteredVocab
      return next {message: "No such term '#{req.params.term}'", status: 404}
    else
    filteredVocab['@context'] = rawVocab['@context']
    rawVocab = filteredVocab

  sendRDF = (errJsonLD, data, contentType) ->
    return next {message: "JSON-LD Error", body: errJsonLD} if errJsonLD
    if contentType is "application/nquads"
      console.info "Nothing to do, data is in the right format"
      res.status 200
      res.set 'Content-Type': contentType
      return res.send data
    else
      RdfUtil.convertN3Sync data, {format: contentType, prefixes: NS.toJSON()}, (errN3, result) ->
        if errN3
          return next {status: 500, message: "N3 error", body: errN3}
        res.status 200
        res.set 'Content-Type': contentType
        return res.send result

  sendJSONLD = (err, data) ->
    return next {message: "JSON-LD Error", body: err} if err
    res.status 200
    res.set 'Content-Type': 'application/ld+json'
    res.json data

  sendHTML = (err, data) ->
    return next {message: "JSON-LD Error", body: err} if err
    res.status 200
    res.set 'Content-Type': 'text/html'
    res.render 'debug-output', data: data

  res.header "Link": "<#{NS.infolis}>" + '; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"'

  res.format
    json: () ->
      # Send a Header like
      # Accept: application/ld+json; q=1, profile="http://www.w3.org/ns/json-ld#flattened"
      if req.header('Accept').indexOf('profile') > -1
        requestedProfile = req.header('Accept').match /profile=\"([^"]+)\"/
        if not requestedProfile or not requestedProfile[1]
          return next { status: 400, message: "Unparseable 'profile' accept-param" }
        switch requestedProfile[1]
          when 'http://www.w3.org/ns/json-ld#flattened' then profile = 'flatten'
          when 'http://www.w3.org/ns/json-ld#compacted' then profile = 'compact'
          when 'http://www.w3.org/ns/json-ld#expanded' then profile = 'expand'
          else return next { status: 406, message: "'profile' accept-param must be from the list" }
      if profile is "expand" then jsonld.expand rawVocab, {expandContext: context}, sendJSONLD
      else jsonld[profile] rawVocab, context, sendJSONLD
    html: () ->
      if profile is "expand" then jsonld.expand rawVocab, {expandContext: context}, sendHTML
      else jsonld[profile] rawVocab, context, sendHTML
    "text/n3": () ->
      return jsonld.toRDF rawVocab, {expandContext: context, format: "application/nquads"}, (err,data) ->
        sendRDF err, data, "text/n3"
    "application/nquads": () ->
      return jsonld.toRDF rawVocab, {expandContext: context, format: "application/nquads"}, (err, data) ->
        sendRDF err, data, "application/nquads"
    "application/trig": () ->
      return jsonld.toRDF rawVocab, {expandContext: context, format: "application/nquads"}, (err, data) ->
        sendRDF err, data, "application/trig"
    "text/turtle": () ->
      return jsonld.toRDF rawVocab, {expandContext: context, format: "application/nquads"}, (err, data) ->
        sendRDF err, data, "text/turtle"

    default: () ->
      res.status(406)
      return res.end()


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
       #    log.info "STEP 2"
       #    call
       #  if previousStepResults.crossRefWorks and
       #     not previousStepResults.crossRefWorks.attachments and
       #     previousStepResults.crossRefWorks.title
       #    googleSearch.searchPDF previousStepResults.crossRefWorks.title, (err, googleResult) ->
       #      callback null, _extend(previousStepResults, {googleSearch:googleResult})
    ], (err, results) ->
      # if err
      #   return sendError(res, "" + JSON.stringify(err)) if err
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

  # Inject reference to MongoDB middleware
  mongoMiddleware = (req, res, next) ->
    req.mongoDB = db
    next()

  # CORS middleware (required for AJAX requests from Primo)
  corsMiddleware = (req, res, next) ->
    res.header 'Access-Control-Allow-Origin', '*'
    res.header 'Access-Control-Allow-Headers', 'Content-Type, X-Requested-With, exlrequesttype'
    next()

  # Error handler
  errorHandler = (err, req, res, next) ->
    log.error err
    res.status err.status || 400
    res.format
      json: () ->
        res.set "Content-Type": "application/problem+json"
        res.json err
      html: () ->
        res.set "Content-Type": "text/html"
        res.render 'error', message: err.message, body: err.body
      default: () ->
        res.set "Content-Type": "text/plain"
        res.set "X-Error-Message": err.message
        res.send JSON.stringify err
  # Templates
  app.set 'views', './views'
  app.set 'view engine', 'jade'

  app.use mongoMiddleware
  app.use corsMiddleware

  ###
  # set up routes
  # NOTE: Must be defined before error handling middleware but after data-injection middleware
  ###
  app.get '/ids-for-id', handle_ids_for_id
  app.get '/doi-info', handle_doi_info
  app.get '/context/gesis', handle_vocab_gesis
  app.get '/context', handle_vocab
  app.get '/vocab', handle_vocab
  app.get '/vocab/:term', handle_vocab
  app.get '/', handle_default

  app.use errorHandler

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
