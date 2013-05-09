class Resource
    constructor: (@name) ->
    load: ->
        return ''
    show: ->
        return ''


class URLBasedResource
    constructor: (@name, @url) ->
    url: ->
        return @_url
    
    load: ->
        elem = document.createElement @tagName
        cont = document.getElementsByTagName('body')[0] or document.getElementsByTagName('head')[0]
        elem.setAttribute @attrName, @url()
        cont.appendChild(elem)

class RImage extends URLBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'IMG'
        @attrName = 'src'
        
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