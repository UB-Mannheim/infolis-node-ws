
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

handle_ids_for_id = (req, res, url_parts) ->
    needle = url_parts.query.id
    console.log needle
    matches = mapping[needle] or []
    if matches.length > 0
        res.writeHead 200, "Content-Type": "application/json"
    else
        res.writeHead 404, "Content-Type": "application/json"
    ret = {
        "needle": needle,
        "matches": matches
    }
    res.end JSON.stringify(ret)


console.log "Loading links"
init()
console.log "Starting server"

handle_default = (req, res, url_parts) =>
    index = fs.readFileSync("index.html")
    res.writeHead 200, "Content-Type": "text/html"
    res.end index

http.createServer((req, res) ->
    url_parts = url.parse(req.url, true)
    console.log url_parts
    if url_parts.pathname is "/ids-for-id"
        handle_ids_for_id(req, res, url_parts)
    else
        handle_default(req, res, url_parts)
    res.end()
    return
).listen 3000
