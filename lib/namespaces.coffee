Namespaces =
    rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
    skos: "http://www.w3.org/2004/02/skos/core#"
    foaf: "http://xmlns.com/foaf/0.1/"
    bibo: "http://purl.org/ontology/bibo/"
    infolis: "http://www-test.bib.uni-mannheim.de/infolis/vocab/"
    rdfs: "http://www.w3.org/2000/01/rdf-schema#"
    rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
    rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
    xsd: 'http://www.w3.org/2001/XMLSchema#'
    dc: 'http://purl.org/dc/elements/1.1/'
    dcterms: 'http://purl.org/dc/terms/'
    dcat: 'http://www.w3.org/ns/dcat#'
    skos: 'http://www.w3.org/2004/02/skos/core#'
    qb: 'http://purl.org/linked-data/cube#'
    owl: 'http://www.w3.org/2002/07/owl#'
    disco: 'http://rdf-vocabulary.ddialliance.org/discovery#'
    foaf: 'http://xmlns.com/foaf/0.1/'
    adms: 'http://www.w3.org/ns/adms#'
    org: 'http://www.w3.org/ns/org#'
    prov: 'http://www.w3.org/ns/prov#'
    xkos: 'http://purl.org/linked-data/xkos#'

    toJSON: () ->
        ret = {}
        for k,v of @ 
            if not (~k.indexOf('_') or ~k.indexOf('to'))
                ret[k] = v 
        return ret
    toJSONLD: () ->
        ret = {'@context': {}}
        for k,v of @toJSON()
            ret['@context'][k] = {'@id': v}
        return ret
    toTurtle: () ->
        ret = ''
        for k,v of @toJSON()
            ret += "@prefix #{k}: <#{v}>.\n"
        return ret

module.exports = Namespaces
