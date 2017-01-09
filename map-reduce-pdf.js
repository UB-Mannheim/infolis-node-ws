db.doi_info.mapReduce(
    function() {
        if (this.zotero) {
            for (att in this.zotero) {
                emit(this.doi, {'pdf':"xxx"+att});
                if (att.url) {
                    //emit(this._id, {'pdf':att.url});
                }
            }
        } else {
            emit(this.doi, {'pdf':null});
        }
    },
    function(key, values) {
        var ret = {}
        ret[key] = values;
        return ret;
    },
    {'out': 'csv_collection'}
);
