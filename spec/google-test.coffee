google = require 'google'

google.resultsPerPage=1

google 'filetype:pdf Toward Health Promotion: Physical and Social Behaviors',  (err, next, links) ->
    if err
        console.log err
        return
    for link in links
        console.log(link)
