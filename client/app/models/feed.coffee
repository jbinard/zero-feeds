module.exports = class Feed extends Backbone.Model

    urlRoot: 'feeds'

    feedClass: ->
        title = $.trim(@attributes.title)
        if title
            title.replace(/[\s!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g,
                          '');
        else
            "none"

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

    links: () ->
        _links = []
        from = @feedClass()
        that = @
        $.each @$items(),
            (index, value) ->
                title = $(value).find("title").text()
                if that.isAtom()
                    url = $(value).find("id").text()
                    description = $(value).find("content").text()
                    if description == ""
                        description = $(value).find("summary").text()
                else
                    url = $(value).find("link").text()
                    description = $(value).find("content\\:encoded").text()
                    if description == ""
                        description = $(value).find("description").text()
                link =
                    "title": title
                    "url": url
                    "from": from
                    "description": description
                _links.push(link)
        _links

    isNew: () ->
        not @id?
