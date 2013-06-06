class Resource
    constructor: (@name) ->
    load: ->
        return ''
    show: ->
        return ''


class URLBasedResource
    constructor: (@name, @_url) ->
    url: ->
        return @_url

    load: ->
        @elem = document.createElement @tagName
        cont = document.getElementsByTagName('body')[0] or document.getElementsByTagName('head')[0]

        attribs = @attribs || {}
        attribs[@attrName] = @url()
        attribs.id = attribs.id || "#{@name}#{new Date().getTime()}"

        for name, value of attribs
            @elem.setAttribute(name, value)

        cont.appendChild(@elem)

    reload: ->
        @elem.remove()
        @load()

    onload: (cb) ->
        @elem.onload = ->
            console.log("loaded", @elem)
            cb()



URLBasedResource::bind = (tag) ->
    return @ unless tag
    atNames =
        IMG: 'src'
        SCRIPT: 'src'

    @elem = tag
    @tagName = tag.tagName
    @attrName = atNames[@tagName]
    @_url = @elem.getAttribute(@attrName)

    @attribs = {}
    attrs = @elem.attributes
    for num in [0..attrs.length-1]
        @attribs[attrs[num].name] = attrs[num].value

    return @

class RImage extends URLBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'IMG'
        @attrName = 'src'

class RStyle extends URLBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'LINK'
        @attrName = 'href'
        @attribs =
            rel: "stylesheet"

class RScript extends URLBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'SCRIPT'
        @attrName = 'src'


class Storage
    constructor: (@name) ->
        @resources = {}

    addResource: (rs) ->
        rs.storage = @
        @resources[rs.name] = rs

    rmResource: (rs) ->
        # TODO

    load: (rsName) ->
        rs = @resources[rsName]
        if rs
            rs.load()
        else
            alert 'no'

    onload: (rsName, cb) ->
        rs = @resources[rsName]
        if rs
            rs.onload(cb)
        else
            alert 'no'





class ScriptWrapper
    constructor: (@window, @ignore) ->
        @G = {}
        for key,value of @window
            @G[key] = value
            delete @window[key]

        @G.window = @G

    difference: () ->
        # get new data from window
        _ = @G._
        keys = _.difference(_.keys(@window), _.keys(@G))
        data = _.pick(@window, keys)
        return data

    eval: (script) ->
        # evaling script in G context and stole new variables from window
        `debugger`
        `
        with (this.G) {
            var r = eval(script);
        }
        `

        data = @difference()
        for key,value of data
            @G[key] = value
            delete @window[key] if key not in @ignore
            console.log('new data:', key, value)

        r




window.s = s = new Storage "jq"
s.addResource(new RScript("jquery", "http://code.jquery.com/jquery-1.9.1.min.js"))
s.addResource(new RScript("underscore", "/js/underscore.js"))
s.addResource(new RStyle("NIHCSS", "/src/NIH.css"))
s.addResource(new URLBasedResource('NIH').bind(document.getElementById('NIHJS')))
s.addResource(new RScript("jquery-ui", "http://code.jquery.com/ui/1.10.3/jquery-ui.js"))

s.load('jquery')
s.load('NIHCSS')
s.load('underscore')
s.onload('underscore', ->
    window.SW = new ScriptWrapper(window, ['SW']);
);



