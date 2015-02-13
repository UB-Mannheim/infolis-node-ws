root = module ? window

cheerio = require 'cheerio'
moment = require 'moment'
extend = require('util')._extend
request = require('request').defaults({jar:true})
http = require 'http'
google = require 'google'
querystring = require 'querystring'

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

#http://sfx.bib.uni-mannheim.de:8080/sfx_local
# ctx_enc=info:ofi/enc:UTF-8
# ctx_id=10_1
# ctx_tim=2015-02-11T13:49:9CET
# ctx_ver=Z39.88-2004
# rfr_id=info:sid/sfxit.com:citation
# rft.date=1983
# rft.genre=article
# rft.issn=0886-6708
# rft.issue=2
# rft.volume=5
# rft_val_fmt=info:ofi/fmt:kev:mtx:journal
# sfx.title_search=contains
# url_ctx_fmt=info:ofi/fmt:kev:mtx:ctx
# url_ver=Z39.88-2004 
#
Sfx = (opts) ->

    for i in "baseurl default_specs".split ' '
        if not opts[i] then return new Error "Must set '#{i}'" else this[i] = opts[i]

    search: (specs, cb) ->
        specs = extend(default_specs, specs)
        specs.ctx_tim =  moment().format("YYYY-MM-DD[T]HH:mm:s[CET]")
        openurl = baseurl + '?' + querystring.stringify(specs)
        console.log(openurl)

GoogleScholar = (opts) ->
    GOOGLE_SCHOLAR_BASEURL = 'http://scholar.google.de/scholar'

    queryUrl = (q) -> 
        args =
            hl: 'de'
            btnG: ''
            lr: ''
            q: q
        return GOOGLE_SCHOLAR_BASEURL + '?' + querystring.stringify(args).replace(/%20/g, '+')

    searchForSpec: (spec, cb) ->
        if not spec or not spec.title or not spec.aulast
            return 'Must set title and aulast'
        url = queryUrl(spec.title + ' ' + spec.aulast)
        request {
            method: 'GET'
            url: url
        }, (err, resp, body) ->
            if err
                return ERROR.COULD_NOT_RETRIEVE(cb, resp.statusCode, url, body)
            $ = cheerio.load(body)
            publink =  $('h3 a').attr('href')
            if not publink
                return ERROR.COULD_NOT_RETRIEVE(cb, resp.statusCode, url, "Couldn't find the first result in here")
            return cb null, publink


GoogleSearch = (opts) ->

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
    Sfx:
        default_specs:
            ctx_id: "10_1"
            ctx_id: "info:ofi/enc:UTF-8"
            ctx_ver: "Z39.88-2004"
            url_ver: "Z39.88-2004"
            rfr_id: "info:sid/sfxit.com:citation"
            rft_val_fmt: "info:ofi/fmt:kev:mtx:journal"
            url_ctx_fmt: "info:ofi/fmt:kev:mtx:ctx"
            'sfx.title_search': "contains"
    GoogleScholar: {}
    CrossRef: {}
    Zotero:
        server: "localhost"
        port: 1234
        agent: 'infolis-crawler'
    GoogleSearch:
        resultsPerPage: 5

root.exports =
    Sfx: (opts) -> Sfx(extend(DEFAULT_OPTIONS.Sfx, opts))
    GoogleScholar: (opts) -> GoogleScholar(extend(DEFAULT_OPTIONS.GoogleScholar, opts))
    Zotero: (opts) -> Zotero(extend(DEFAULT_OPTIONS.Zotero, opts))
    CrossRef: (opts) -> CrossRef(extend(DEFAULT_OPTIONS.CrossRef, opts))
    GoogleSearch: (opts) -> GoogleSearch(extend(DEFAULT_OPTIONS.GoogleSearch,opts))
