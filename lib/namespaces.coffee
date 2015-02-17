Namespaces =
    adms: 'http://www.w3.org/ns/adms#'
    bibo: "http://purl.org/ontology/bibo/"
    dcat: 'http://www.w3.org/ns/dcat#'
    dc: 'http://purl.org/dc/elements/1.1/'
    dcterms: 'http://purl.org/dc/terms/'
    disco: 'http://rdf-vocabulary.ddialliance.org/discovery#'
    foaf: 'http://xmlns.com/foaf/0.1/'
    foaf: "http://xmlns.com/foaf/0.1/"
    infolis: "http://www-test.bib.uni-mannheim.de/infolis/vocab/"
    org: 'http://www.w3.org/ns/org#'
    owl: 'http://www.w3.org/2002/07/owl#'
    prov: 'http://www.w3.org/ns/prov#'
    qb: 'http://purl.org/linked-data/cube#'
    rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
    rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
    rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
    rdfs: "http://www.w3.org/2000/01/rdf-schema#"
    schema: "http://schema.org/"
    skos: 'http://www.w3.org/2004/02/skos/core#'
    xkos: 'http://purl.org/linked-data/xkos#'
    xsd: 'http://www.w3.org/2001/XMLSchema#'

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
