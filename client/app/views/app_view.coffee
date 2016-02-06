View       = require '../lib/view'
AppRouter  = require '../routers/app_router'
FeedsView  = require './feeds_view'
ParamsView = require './params_view'
Feed       = require '../models/feed'

module.exports = class AppView extends View
    el: 'body.application'

    template: ->
        require('./templates/home')

    events:
        "click .menu-new": "displayNewForm"
        "click .menu-help": "toggleHelp"
        "click .menu-settings": "toggleSettings"
        "click .menu-import": "import"
        "change #feeds-file": "uploadFile"

        "submit form.new-feed": "addFeed"

        "keyup #param-cozy-bookmarks-name": "updateSettings"
        "change #param-show-new-links": "toggleOldLinks"

        "click .link-send-to-cozy-bookmarks": "toCozyBookMarks"
        "click .link": "linkDetails"

    startWaiter: ($elem) ->
        html = "<img " +
               "src='images/loader.gif' " +
               "class='main loader' " +
               "alt='loading ...' />"
        $elem.append html

    stopWaiter: ($elem) ->
        $elem.find(".main.loader").remove()

    toggleOldLinks: (evt) ->
        $("ul.links").toggleClass("show-old")
        @updateSettings(evt)
        false

    applyParameters: (parameters) ->
        # TODO: check what to do for cozy bookmarks update
        for parameter in parameters
            if parameter.paramId is "show-new-links"
                if parameter.value is "false"
                    @toggleOldLinks()
                    break

    afterRender: ->
        @feedsView = new FeedsView()
        @startWaiter(@feedsView.$el)
        @feedsView.collection.fetch
            success: =>
                @stopWaiter(@feedsView.$el)

        @paramsView = new ParamsView()
        @startWaiter(@paramsView.$el)
        @paramsView.collection.fetch
            success: (view, parameters) =>
                @applyParameters(parameters)
                @stopWaiter(@paramsView.$el)
        if $(".feeds").width() / $("body").width() < 10
            $(".feeds").css("max-width", "17em")

    initialize: ->
        @router = CozyApp.Routers.AppRouter = new AppRouter()

    hideToggled: ->
        $(".new-feed").slideUp()
        $("div.help").slideUp()
        $("form.settings").slideUp()
        $(".menu-buttons .active").removeClass 'active'

    displayNewForm: ->
        @hideToggled()
        unless $(".new-feed").is(':visible')
            $(".menu-new").addClass 'active'
            $(".new-feed").slideDown()
            $(".new-feed-url").focus()
        false

    toggleHelp: ->
        @hideToggled()
        unless $("div.help").is(':visible')
            $(".menu-buttons .btn.help").addClass 'active'
            $("div.help").slideDown()
        false

    toggleSettings: ->
        @hideToggled()
        unless $("form.settings").is(':visible')
            $(".menu-buttons .btn.cog").addClass 'active'
            $("form.settings").slideDown()
        false

    cleanAddFeedForm: ->
        $("form.new-feed").find("input").val("")

    cleanAddFeedForm: ->
        $("form.new-feed").find("input").val("")

    createFeed: (evt, url, tags) ->
        feed = new Feed
            url: url
            tags: tags
        @feedsView.collection.create feed,
            success: (elem) =>
                elems = $("." + elem.cid)
                elems.parents(".tag").find(".feed").show()
                @cleanAddFeedForm()
                elems.not(".clone").click()
            error: =>
                View.error "Server error occured, feed was not added"

    addFeed: (evt) =>
        url  = $('.new-feed-url').val()
        tags = $('.new-feed-tags').val().split(',').map (tag) -> $.trim(tag)

        if url?.length > 0
            @createFeed(evt, url, tags)
            evt.preventDefault()
        else
            View.error "Url field is required"

        false

    updateSettings: (evt) =>
        if not evt
            return false
        for parameter in @paramsView.collection.models
            paramId = "param-" + parameter.attributes.paramId
            name    = parameter.attributes.name
            $elem = $("#param-" + paramId)
            if paramId is "param-show-new-links" and paramId is evt.target.id
                checked = $elem.prop("checked")
                parameter.save { "value": checked },
                    success: () ->
                        View.log name + " saved"
                    error: () ->
                        View.error name + " not saved"
                break
            else if paramId is evt.target.id
                app = $elem.val()
                if @settingsSaveTimer?
                    clearTimeout @settingsSaveTimer
                @settingsSaveTimer = setTimeout (() ->
                    parameter.save { "value": app },
                        success: () ->
                            View.log name + " saved"
                        error: () ->
                            View.error name + " not saved")
                    , 1000
                break

        false

    toCozyBookMarks: (evt) =>
        console.log("oooooo")
        url = $(evt.target).parents(".link:first").find("> a").attr("href")
        ajaxOptions =
            type: "POST",
            url: "../../apps/" + $("#param-cozy-bookmarks-name").val() + "/bookmarks",
            data: { url: url, tags: ["cozy-feeds"] }
            success: () ->
                View.log "link added to cozy-bookmarks"
            error: () ->
                View.error "link wasn't added to cozy-bookmarks"
        $.ajax(ajaxOptions)
        false

    linkDetails: (evt) =>
        link = $(evt.currentTarget)
        link.toggleClass "link-active"
        link.find(".link-view-description").toggleClass "link-active"
        link.find(".link-description").toggle()

    addFeedFromFile: (feedObj) ->
        feed = new Feed feedObj
        @feedsView.collection.create feed,
            success: (elem) =>
                imported = $(".imported")
                if imported.text()
                    imported.text(parseInt(imported.text()) + 1)
                else
                    imported.text(1)
                $("." + elem.cid).parents(".tag").find(".feed").show()
            error: =>
                notImported = $(".import-failed")
                if notImported.text()
                    notImported.text(parseInt(notImported.text()) + 1)
                else
                    notImported.text(1)

    addFeedFromHTMLFile: (link) ->
        $link = $ link
        if $link.attr("feedurl")
            url         = $link.attr "feedurl"
            title       = $link.text()
            description = ""
            next = $link.parents(":first").next()
            if next.is("dd")
                description = next.text()
            feedObj =
                url: url
                tags: [""]
                description: description
            @addFeedFromFile feedObj

    addFeedsFromHTMLFile: (loaded) ->
        links = loaded.find "dt a"
        for link in links
            @addFeedFromHTMLFile link

    addFeedFromOPMLFile: (link, tag) ->
        $link = $ link
        if $link.attr("xmlUrl")
            url         = $link.attr "xmlUrl"
            title       = $link.attr "title"
            description = $link.attr "text"

            feedObj =
                url: url
                tags: [tag]
                description: description
            @addFeedFromFile feedObj

    addFeedsFromOPMLFile: (loaded) ->
        links = loaded.find "> outline"
        for link in links
            $link = $ link
            if $link.attr("xmlUrl")
                @addFeedFromOPMLFile link, ""
            else
                tag = $link.attr("title")
                taggedLinks = $link.find "outline"
                for taggedLink in taggedLinks
                    @addFeedFromOPMLFile taggedLink, tag

    addFeedsFromFile: (file) ->
        loaded = $(file)
        if loaded.is("opml")
            @addFeedsFromOPMLFile loaded
        else
            @addFeedsFromHTMLFile loaded

    isUnknownFormat: (file) ->
        return file.type isnt "text/html" and file.type isnt "text/xml" and
            file.type isnt "text/x-opml+xml"

    uploadFile: (evt) ->
        file = evt.target.files[0]
        if @isUnknownFormat file
            View.error "This file cannot be imported"
            return

        reader = new FileReader()
        reader.onload = (evt) => @addFeedsFromFile(evt.target.result)
        reader.readAsText(file)

    import: (evt) ->
        View.confirm "Import opml rss file or " +
                          "html bookmarks file containing feeds exported by " +
                          "firefox or chrome",
            () -> $("#feeds-file").click()
