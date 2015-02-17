N3 = require 'n3'
async = require 'async'
log = require('./logging').defaultLogger

module.exports = 
  
    convertN3Sync: (data, opts, callback) ->
      async.waterfall([
        (next) => 
          @parseN3Sync data, (errParse, triples) =>
            return next errParse if errParse
            return next null, triples
        (triples, next) =>
          @writeN3Sync triples, opts, (errWrite, result) ->
            if errWrite
              return next errWrite 
            return next null, result
      ], callback)


    writeN3Sync: (triples, opts, callback) ->
      if not opts or not callback
        callback "Must pass 'opts' and 'callback' to writeN3Sync"
      n3Writer = N3.Writer(opts)
      for t in triples
        n3Writer.addTriple t
      n3Writer.end (err, data) ->
        log.warn err
        if err and err isnt {}
          callback err, data
        else
          callback null, data

    parseN3Sync: (data, callback) ->
        n3Parser = N3.Parser()
        triples = []
        doneParsing = false
        async.until(
            () -> doneParsing
            (doneParsingCallback) ->
                n3Parser.parse data, (errN3Parser, triple) ->
                    if errN3Parser
                        doneParsing = true
                        return doneParsingCallback(errN3Parser)
                    else if not triple
                        doneParsing = true
                        return doneParsingCallback()
                    else 
                        return triples.push triple 
            (err) -> callback err, triples
        )


