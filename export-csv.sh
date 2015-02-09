#!/bin/bash
FIELDS="_id,doi,crossRefWorks.DOI,zotero.0.attachments.0.url,zotero.0.attachments.1.url"
#FIELDS="_id,doi,crossRefWorks.DOI"
mongoexport \
    --db infolis \
    --collection doi_info \
    --csv \
    --fields $FIELDS \
    --out stuff.csv
