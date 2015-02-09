doi_module = require '../doi.coffee'

logit = (msg...) ->
    console.log("foo")
    console.log(x) for x in msg

describe 'DOI module test suite', () ->
    doi = {}
    beforeEach ->
        doi = new doi_module
    it 'knows its tautologies', ->
        expect(true).toBe true
    it 'has the right base', ->
        expect(doi.CROSSREF_API_URL).toBe 'http://api.crossref.org'
    it 'correctly detects valid/invalid DOIs', ->
        valid_dois = [
            '10.3886/ICPSR00064.v1'
        ]
        invalid_dois = [
            '11.3886/ICPSR00064.v1'
        ]
        for x in valid_dois
            expect(doi.isValidDOI(x)).toBe(true)
        for x in invalid_dois
            expect(doi.isValidDOI(x)).toBe(false)
    it 'successfully retrieves the agency for a DOI', ->
        expected =
            '10.3886/ICPSR00064.v1': { id: 'datacite', label: 'DataCite'}
        received_no = 0
        expected_no = (k for own k of expected).length
        runs () ->
            for k,v of expected
                doi.getAgencyForDOI doi, (err, x) ->
                    expect(x).toEqual v
                    received += 1
        waitsFor( 
            () -> received_no is not expected_no
            'HTTP should return',
            800)
        runs() ->
            console.log(received)

