# !./node_modules/coffee-script/bin/coffee %

async = require 'async'
http = require("http")
csv = require("csv")
fs = require("fs")
url = require("url")
mapping = {}
index = ""

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
        return

      console.log cur  if cur % 500 is 0
    return

  links.write file_links
  links.end()
  return

_matches_to_objects = (matches) ->
    ret = []
    for id in matches
        ret.push {
            "@type": "MatchResult",
            "accuracy": Math.random(),
            "id": id
        }
    ret

handle_ids_for_id = (req, res, url_parts) ->
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

handle_default = (req, res, url_parts) ->
    # just for debugging
    index = fs.readFileSync("index.html")
    res.writeHead 200, "Content-Type": "text/html"
    res.end index

handle_doi_info = (req, res, url_parts) ->
    ret = {}
    async.series [

        # Ask for the agency
        (cb) ->
            url = 'http://api.crossref.org/works/' + url_parts.query.doi + '/agency'
            http.get url, (api_res) ->
                api_res.on 'data', (chunk) ->
                    msg = JSON.parse(chunk.toString())
                    ret.doi_agency = msg.message.agency
                    ret.doi = msg.message.doi
                    cb()
        # Ask for metadata
        (cb) ->
            url = 'http://api.crossref.org/works/' + url_parts.query.doi
            http.get url, (api_res) ->
                api_res.on 'data', (chunk) ->
                    msg = JSON.parse(chunk.toString())
                    console.log msg.message
                    ret.stuff = msg.message
                    cb()
        # Resolve the DOI and query Zotero web service for more information on this
        # TODO
        ],
        (err, results) ->
            res.writeHead 200, "Content-Type": "application/json"
            res.end JSON.stringify ret

http.createServer((req, res) ->
    res.setHeader "Access-Control-Allow-Origin", "*"
    res.setHeader "Access-Control-Allow-Headers", "X-Requested-With, exlrequesttype"
    url_parts = url.parse req.url, true
    action = url_parts.pathname.split('/').pop()
    console.log url_parts
    console.log action
    if action is "ids-for-id"
        handle_ids_for_id(req, res, url_parts)
    else if action is "doi-info"
        handle_doi_info(req, res, url_parts)
    else
        handle_default(req, res, url_parts)
).listen 3000
