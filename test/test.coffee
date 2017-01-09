{Sfx,Zotero} = require 'lib/pubres'
logit = (err, stuff) ->
    if (err)
        console.log("ERROR!")
        console.log(err)
    else
        console.log(stuff)
# #pubres.Zotero.scrapePage("http://www.tandfonline.com/doi/abs/10.1080/154240609", logit )
# pubres.Zotero.scrapePage("http://www.nature.com/onc/journal/v31/n6/full/onc2011282a.html", logit )
#
#
#

sfx = new Sfx
    baseurl: "http://sfx.bib.uni-mannheim.de:8080/sfx_local"
    db: 1
console.log sfx.search
    'doi_id': '10.1016/j.ctcp.2007.03.00'
