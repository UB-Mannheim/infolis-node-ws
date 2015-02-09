root = module ? window

extend = require('util')._extend
request = require('request').defaults({jar:true})
http = require 'http'
google = require 'google'

_err = (code, id, msg, body) ->
    ret = 
        statusCode: code
        error_id: id
        error_msg: msg
    ret.body = body if body
    return ret

ERROR =
    COULD_NOT_RETRIEVE         : (cb, statusCode, url, body) -> cb _err(statusCode, "COULD_NOT_RETRIEVE", "Could not retrieve #{url}.", body)
    COULD_NOT_RESOLVE_REDIRECT : (cb, statusCode, url) -> cb _err(statusCode, "COULD_NOT_RESOLVE_REDIRECT", "Could not resolve #{url}.")
    COULD_NOT_RETRIEVE_JSON    : (cb, statusCode, url, body) -> cb _err(statusCode, "COULD_NOT_RETRIEVE_JSON", "Could not retrieve JSON from #{url}.", body)
    ZOTERO_NO_TRANSLATION      : (cb, url, body) -> cb _err(-1, "ZOTERO_NO_TRANSLATION", "Zotero could not translate #{url}.", body)
    BAD_JSON                   : (cb, url, body) -> cb _err(-2, "BAD_JSON", "#{url}: This is not valid JSON!", body)
    GOOGLE_ERROR               : (cb, needle, err) -> cb _err(-3, "GOOGLE_ERROR", "Couldn't fetch results for '#{needle}' because", err)

sensibleAgent = new http.Agent()
sensibleAgent.maxSockets = 20

httpGetJSON = (url, cb) ->
    request_options =
        method: 'GET'
        json: true
        url: url
    request request_options, (err, resp, body) ->
        if err or not resp or resp.statusCode != 200 then return ERROR.COULD_NOT_RETRIEVE_JSON(cb, 500, url, body)
        cb null, body

GoogleSearch = (opts) ->

    if not opts.db
        return new Error('Must set MongoDB')

    google.resultsPerPage = opts.resultsPerPage

    searchPDF : (needle, cb) ->
        google 'filetype:pdf ' + needle, (err, next, links) ->
            if err then return ERROR.GOOGLE_ERROR(cb, needle, err)
            console.log links[0]
            if links[0]
                cb null, links[0].link
            else
                cb null, null

Zotero = (opts) ->

    if not opts.db
        return new Error('Must set MongoDB')

    scrapeDOI : (doi, cb) ->
        self = this
        request 'http://doi.org/' + encodeURIComponent(doi), (err, resp, body) ->
            return cb err if err
            self.scrapePage resp.request.uri.href, cb

    scrapePage : (url, cb) ->
        console.log "Zotero.scrapePage #{url}"
        request_options =
            url: "http://#{opts.server}:#{opts.port}/web"
            method: 'POST'
            json: true
            body:
                url: url
                sessionid: "foobar"
            headers:
                'User-Agent': opts.agent
                'Content-Type': 'application/json'
        request request_options, (err, resp, body) ->
            if err
                console.log err
                return cb err
            else if resp.statusCode == 200
                if body.length == 0
                    return ERROR.ZOTERO_NO_TRANSLATION(cb, url)
                else
                    # SUCCESS
                    return cb null, body
            else
                return ERROR.COULD_NOT_RETRIEVE(cb, resp.statusCode, url, body)

CrossRef = (opts) ->

    if not opts.db
        return new Error('Must set MongoDB')

    CROSSREF_API_URL : "http://api.crossref.org"

    # https://github.com/zotero/translators/blob/master/DOI.js#L34
    DOI_REGEX : ///
        \b10\.                      # 10.
        [0-9]{4,}                   # Registrant id
        /[^\s&"\']*[^\s&"\'.,]\b   # identifier of the document
    ///

    isValidDOI : (doi) ->
        DOI_REGEX.test(doi)

    getPrefix : (doi) ->
        doi.substring doi.indexOf('/')

    urlForWorks : (doi) -> @CROSSREF_API_URL + "/works/#{doi}"

    urlForAgency : (doi) -> @CROSSREF_API_URL + "/works/#{doi}/agency"

    getAgencyForDOI : (doi, cb) ->
        httpGetJSON @urlForAgency(doi), (err, data) ->
            if not err then data = data.message.agency
            cb err, data

    getBibliographicMetadataForDOI : (doi, cb) ->
        httpGetJSON @urlForWorks(doi), (err, data) ->
            if not err then data = data.message
            cb err, data

DEFAULT_OPTIONS =
    CrossRef: {}
    Zotero:
        server: "localhost"
        port: 1234
        agent: 'infolis-crawler'
    GoogleSearch:
        resultsPerPage: 5

root.exports =
    Zotero: (opts) -> Zotero(extend(DEFAULT_OPTIONS.Zotero, opts))
    CrossRef: (opts) -> CrossRef(extend(DEFAULT_OPTIONS.CrossRef, opts))
    GoogleSearch: (opts) -> GoogleSearch(extend(DEFAULT_OPTIONS.GoogleSearch,opts))
