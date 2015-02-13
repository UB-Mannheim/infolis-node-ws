#!/bin/bash

export_pdfs() {
    FIELDS="_id,doi,zotero.0.attachments.0.url,zotero.0.attachments.1.url"
    #FIELDS="_id,doi,crossRefWorks.DOI"
    mongoexport \
        --db infolis \
        --collection doi_info \
        --csv \
        --fields $FIELDS \
        --out stuff.csv
}

BAD_DOI_FIELDS="doi"
mongoexport \
    --db infolis \
    --collection doi_info \
    --csv \
    --fields $BAD_DOI_FIELDS \
    --query "{'\$or': [{'zotero':{'\$exists':false}}, {'zotero':null}]}" \
    --out bad_dois.csv

