module.exports = class Feed extends Backbone.Model

    urlRoot: 'feeds'

    titleText: () ->
        if @attributes.title
            title = @attributes.title
        else
            if @isAtom()
                title = @toXml().find("feed > title:first").text()
            else
                title = @toXml().find("channel > title:first").text()
        $.trim(title)

    toXml: () ->
        if @changed || !@_xml
            @_$xml = $($.parseXML(@attributes.content))
        @_$xml

    isAtom: () ->
        @toXml().find("feed").length > 0

    $items: () ->
        if @isAtom()
            @toXml().find("entry").get()
        else
            @toXml().find("item").get()
    
    cleanGoogle: (url) ->
        if url.startsWith("http://news.google.com") or url.startsWith("https://news.google.com")
            url = url.split("url=")[1]

        url

    count: () ->
        last  = @attributes.last
        items = @$items()
        nbNew = 0
        $.each items,
            (index, value) =>
                if @isAtom()
                    url = $(value).find("link").attr("href")
                else
                    url = $(value).find("link").text()
                if last and @cleanGoogle(url) == @cleanGoogle(last)
                    return false
                nbNew++
        nbNew

    links: (options) ->
        _links = []
        from   = options.feedClass
        state  = "new"
        last   = @attributes.last
        items  = @$items()
        $.each items,
            (index, value) =>
                title = $(value).find("title").text()
                if @isAtom()
                    url = $(value).find("link").attr("href")
                    description = $(value).find("content").text()
                    if description == ""
                        description = $(value).find("summary").text()
                else
                    url = $(value).find("link").text()
                    description = $(value).find("content\\:encoded").text()
                    if description == ""
                        description = $(value).find("description").text()
                if last and url == last
                    state = "old"
                link =
                    "title": title
                    "encodedTitle": encodeURIComponent title
                    "url": url
                    "from": from
                    "state": state
                    "description": description
                if index == 0
                    @last = link.url
                _links.push(link)
        _links

    isNew: () ->
        not @id?
