moment = require 'moment'
tabletojson = require 'tabletojson'
fs = require 'fs'

parse_crossref_date = (raw) ->
    parsed = moment(raw, "MMM DD, YYYY", "en")
    return if parsed.isValid() then parsed else null

fs.readFile 'doi-prefixes.html', (err, data) ->
    return console.log(err) if err
    tables = tabletojson.convert(data)

    expanded = []
    cur_line = 0
    for row in tables[7]
        if cur_line++ > 0 then expanded.push
            _id: row[1]
            prefix: row[1]
            name: row[0]
            date_joined: parse_crossref_date row[2]
            date_last_deposit: parse_crossref_date row[3]
            date_last_query: parse_crossref_date row[4]
    fs.writeFile('doi-prefixes.json', JSON.stringify(expanded, null, 2))
