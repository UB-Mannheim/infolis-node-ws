test = require 'tape'

{GoogleScholar} = require '../lib/pubres'

test 'sanity', (t) ->
    t.plan(2)
    t.ok GoogleScholar, 'Module is loaded'
    gsch = new GoogleScholar
    t.ok gsch, 'Instantiated'

test 'correct link is found', (t) ->
    tests = [
        { 
            spec:
                title:'Predictors of complementary and alternative medicine use among older Mexican Americans'
                aulast:'Loera'
            expected: 'http://www.sciencedirect.com/science/article/pii/S1744388107000060'
        }
        { 
            spec:
                title:'Gender Differences in Social Relationships, Social Integration and Substance Use'
                aulast:'Jones-Johnson'
            expected: 'http://www.scirp.org/journal/PaperInformation.aspx?PaperID=27275'
        }
    ]
    t.plan tests.length * 3
    gsch = new GoogleScholar
    tests.forEach (def) ->
        {spec, expected} = def
        gsch.searchForSpec spec, (err, url) ->
            t.notOk err, 'No error was thrown'
            t.ok url, "URL was returned"
            t.equal url, expected


