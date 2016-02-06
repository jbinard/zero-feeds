View         = require '../lib/view'
linkTemplate = require './templates/link'
tagTemplate  = require './templates/tag'

module.exports = class FeedView extends View
    className: 'feed'
    tagName: 'div'

    constructor: (@model, clone) ->
        @clone = clone
        super()

    template: ->
        template = require './templates/feed'
        template @getRenderData()

    events:
        "click": "onUpdateClicked"
        "click .feed-count": "setUpdate"
        "click .feed-delete": "onDeleteClicked"
        "mouseenter .feed-delete": "setToDelete"
        "mouseleave .feed-delete": "setToNotDelete"

    startWaiter: () ->
        @$el.addClass("loading")

    stopWaiter: () ->
        @$el.removeClass("loading")

    setToDelete: () ->
        @$el.addClass("to-delete")

    setToNotDelete: () ->
        @$el.removeClass("to-delete")

    addToTag: (tag) ->
        tmpl = tagTemplate
        tag  = tag or "untagged"

        tagPlace = $ "." + tag
        if tagPlace.length is 0
            tagPlace = $(tmpl({ "name": tag }))
            $("#content .feeds").append tagPlace

        exists = tagPlace.find "." + @model.cid
        if $("." + @model.cid).length
            elem = new FeedView(@model, true).$el
            elem.addClass("clone")
        else
            elem = @$el

        if exists.length
            exists.replaceAll elem
        else
            tagPlace.find(".tag-header").after elem

    setCount: () ->
        count = @model.count()
        if count
            @$el.find(".feed-count").html "(" + count + ")"
        else
            @$el.find(".feed-count").html ""

    setUpdate: () ->
        if @$el.is ":visible"
            @startWaiter()
            @model.save { "content": "" },
                success: =>
                    @stopWaiter()
                    @setCount()
                    setTimeout _.bind(@setUpdate, @),
                         ((1 + Math.floor(Math.random()*14)) * 60000)
                error: =>
                    @stopWaiter()
                    setTimeout _.bind(@setUpdate, @),
                         ((11 + Math.floor(Math.random()*14)) * 60000)
        false

    render: ->
        @$el.html @template({})
        @$el.addClass(@model.cid)

        if @clone
            return

        tags = @model.attributes.tags or ["untagged"]
        if typeof tags is "string"
            tags = tags.split ","
        for tag in tags
            @addToTag(tag)

        @

    feedClass: ->
        title = $.trim(@model.attributes.title)
        if title
            title.replace(/[\s!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g,
                          '')
        else
            "link" + @model.cid

    renderXml: ->
        withCozyBookmarks = $("#cozy-bookmarks-name").val()

        tmpl   = linkTemplate

        links  = @model.links
            "feedClass": @feedClass()
        if not links.length
            View.error "No link found, are you sure that the url is correct ?"
            return
        links.reverse()
        $.each links,
            (index, link) ->
                link.toCozyBookMarks = withCozyBookmarks
                $(".links").prepend($(tmpl(link)))

    onUpdateClicked: (evt) ->
        @startWaiter()
        evt.preventDefault()

        $allThat      = $("." + @model.cid)
        existingLinks = $(".links ." + @feedClass() + ", .link" + @model.cid)
        if existingLinks.length
            existingLinks.remove()
            $allThat.removeClass "showing"
            @setCount()
            @stopWaiter()
        else
            try
                title = @model.titleText()
            catch error
                @stopWaiter()
                View.error "Can't parse feed, please check feed address."
                return false

            $allThat.addClass "showing"
            @model.save { "title": title, "content": "" },
                success: =>
                    @stopWaiter()
                    @renderXml()
                    title = @model.titleText()
                    if title
                        last  = @model.last
                        @model.save { "title": title, "last": last, "content": "" }
                        $allThat.find("a").html title
                        View.log "" + title + " reloaded"
                error: =>
                    @stopWaiter()
                    View.error "Server error occured, feed was not updated."
        false

    refillAddForm: ->
        title = @$el.find(".feed-title")
        url   = title.attr("href")
        tags  = title.attr("data-tags") or ""

        $("form.new-feed .url-field").val(url)
        $("form.new-feed .tags-field").val(tags)

        unless $('.new-feed').is(':visible')
            $('.new').trigger 'click'

    fullRemove: ->
        myTag = @$el.parents(".tag")
        if myTag.find(".feed").length is 1
            myTag.remove()

        @destroy()

        existingLinks = $(".links ." + @feedClass() + ", .link" + @model.cid)
        if existingLinks.length
            existingLinks.remove()

        $(".clone." + @model.cid).remove()

    onDeleteClicked: (evt) ->
        @model.destroy
            success: =>
                @refillAddForm()
                @fullRemove()
                title = @model.titleText()
                if title
                    View.log "" + title + " removed and placed in form"
            error: =>
                View.error "Server error occured, feed was not deleted."
        evt.preventDefault()

        false
