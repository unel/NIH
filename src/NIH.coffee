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


s = new Storage "jq"
s.addResource(new RScript("jquery", "http://code.jquery.com/jquery-1.9.1.min.js"))
s.load('jquery')
window.s = s
s.addResource(new URLBasedResource('NIH').bind(document.getElementById('NIHJS')))
s.addResource(new RStyle("NIHCSS", "src/NIH.css"));
s.load('NIHCSS');