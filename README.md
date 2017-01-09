infolis helper webservices
==========================

**OBSOLETE**

Requires NodeJS and a running MongoDB

Start with
```
./run.js debug
```

Available endpoints:

`/doi-info?doi=10.????/???????`

* Retrieves information about a URI from CrossRef then resolves the DOI to a URL and scrapes the page with Zotero
* Stores the raw JSON responses from CrossRef and Zotero in the 'doi_info' collection

`/id-for-id?id=<URN|DOI>`

* Resolves URN to DOI and vice versa from the links.csv file


## Relevant Mongo queries

Find the docs where zotero translation failed
```
db.getCollection('doi_info').find({'$or': [{'zotero':{'$exists':false}}, {'zotero':null}]}).count()
```
