fs = require 'fs'
request = require 'request'
async = require 'async'
querystring = require 'querystring'
cheerio = require 'cheerio'
{Zotero} = require 'lib/pubres'

GOOGLE_SCHOLAR_BASEURL = 'http://scholar.google.de/scholar'
LOCAL_FILE = 'google-scholar-test.html'
zotero = new Zotero({'db':1})
queryUrl = (q) -> 
    args =
        hl: 'de'
        btnG: ''
        lr: ''
        q: q
    return GOOGLE_SCHOLAR_BASEURL + '?' + querystring.stringify(args).replace(/%20/g, '+')

url = queryUrl('Predictors of complementary and alternative medicine use among older Mexican Americans')
async.waterfall [
    (cb) -> 
        fs.exists LOCAL_FILE, (exists) ->
            if (not exists)
                request {
                    method: 'GET'
                    url: url
                }, (err, resp, body) ->
                    fs.writeFile LOCAL_FILE, body, (err) ->
                        if err
                            console.log("ERROR couldn't write file: #{err}")
                            return cb "ERROR reading"
                        console.log("DONE")
                        return cb()
            else
                return cb()
    (cb) ->
        fs.readFile LOCAL_FILE, (err, buf) -> 
            if err
                console.log("ERROR couldn't read file: #{err}")
                return cb "ERROR"
            rawHTML = buf.toString()
            $ = cheerio.load(rawHTML)
            publink =  $('h3 a').attr('href')
            return cb null, publink
    (publink, cb) ->
        if not publink
            return cb 'ERROR No link for Zotero'
        zotero.scrapePage publink, (err, json) ->
            console.log json
], (err) ->
    console.log err
