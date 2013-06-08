class Resource
    constructor: (@name) ->
    load: -> ''
    rqdata: -> ''

class URLBasedResource
    constructor: (@name, @_url) ->
    url: ->
        return @_url

    rqdata: -> @url()
    mkTag: ->
        elem = document.createElement @tagName
        elem.style.display = "none"

        attribs = @attribs || {}
        attribs[@attrName] = @url()
        attribs.id = attribs.id || "#{@name}#{new Date().getTime()}"

        for name, value of attribs
            elem.setAttribute(name, value)

        return elem

    load: ->
        return true if @elem

        @elem = @mkTag()
        cont = document.getElementsByTagName('body')[0] or document.getElementsByTagName('head')[0]
        cont.appendChild(@elem)

        return true

    load_a: (cbS, cbE, cbF) ->
        if @elem
            safeCall(cbS, @)
            safeCall(cbF, @)
            return

        @elem = @mkTag()

        @elem.onload = =>
            safeCall(cbS, @)
            safeCall(cbF, @)

        @elem.onerror = =>
            safeCall(cbE, @)
            safeCall(cbF, @)


        cont = document.getElementsByTagName('body')[0] or document.getElementsByTagName('head')[0]
        cont.appendChild(@elem)


        return

    reload: ->
        @elem.remove()
        @elem = null
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
    constructor: (@name, @_url, @opt) ->
        @opt ?= {}
        @module = new JSModule(@url(), window, @opt)
        @tagName = 'SCRIPT'
        @attrName = 'src'
        attribs = {
            type: "text/javascript"
        }

    rqdata: ->
        return undefined unless @opt.export
        if @opt.export.length > 1
            ret = {}
            for field in @opt.export
                ret[field] = @module.Globals[field]

        else if @opt.export.length == 1
            ret = @module.Globals[@opt.export[0]]

    load_a: (cbS, cbE, cbF) ->
        requirements = @opt.require || []
        NIH.STORAGE.loads(requirements,
            (resources) =>
                scripts = (resources[rsName] for rsName in requirements \
                           when resources[rsName].constructor.name is "RScript")
                ectx = {}
                for script in scripts
                    for varName in script.opt.export
                        ectx[varName] = script.module.Globals[varName]

                @module.ectx = ectx
                @module.load_a(
                    => cbS(@)
                    => cbE(@)
                    => cbF(@)
                )

            (resources) =>
                cbE(@)
                cbF(@)
        )

RScript.FromJSModule = (name, globals, opt) ->
    rs = new RScript(name, "", opt)
    rs.module.Globals = globals
    rs.module.code = "1"

    return rs

class JSModule
    constructor: (@url, @window, @opt) ->
        @opt ?= {}
        @Globals = {}

    load: ->
        self = this
        return true if @code

        ret = false

        AJAX.GET(@url, {
            onSuccess: (xhr) =>
                @code = xhr.responseText
                self.do(@code)
                ret = true

            onError: (xhr) ->
                ret = false
        })

        return ret

    load_a: (cbS, cbE, cbF) ->
        if @code
            safeCall(cbS)
            safeCall(cbF)
            return

        AJAX.GET(@url, {
            async: true,
            onSuccess: (xhr) =>
                @code = xhr.responseText
                @do(@code)
                safeCall(cbS)
                safeCall(cbF)

            onError: (xhr) =>
                safeCall(cbE)
                safeCall(cbF)
        })

    preabsorbe: ->
        @oldKeys = {}
        @oldKeys[key] = value for key,value of @window
        @ectx ?= {}

    absorbe: ->
        for key,value of @window
            if !@oldKeys.hasOwnProperty(key)
                @Globals[key] = value
                delete @window[key] if key not in ['NIH']

        for key,value of @ectx
            if !@oldKeys.hasOwnProperty(key)
                @Globals[key] = value

        @ectx = {}
        delete @oldKeys


    do: (code) ->
        @preabsorbe()
        `
        var ret;
        with(this.ectx){
            with(this.Globals){
                try{
                    ret = eval(code);

                } catch(err) {
                    throw err;
                }

            }
        }`
        @absorbe()


        return ret

class Storage
    constructor: (@name, resourcesInfo) ->
        @resources = {}

        rsMethods = {
            "scripts": "addScript",
            "styles": "addStyle",
            "images": "addImage",
            "modules": "addScriptFromModule"
        }
        if resourcesInfo
            for rsType,resources of resourcesInfo
                rsMethod = rsMethods[rsType]
                continue unless rsMethod

                for name,args of resources
                    args = [args] if !TYPES.isArray(args)
                    @[rsMethod](name, args[0], args[1])

    addResource: (rs) ->
        rs.storage = @
        @resources[rs.name] = rs

    addScript: (name, url, opt) ->
        @addResource(new RScript(name, url, opt))

    addImage: (name, url, opt) ->
        @addResource(new RImage(name, url, opt))

    addStyle: (name, url, opt) ->
        @addResource(new RStyle(name, url, opt))

    addScriptFromModule: (name, globals, opt) ->
        @addResource(RScript.FromJSModule(name, globals, opt))

    rmResource: (rs) ->
        # TODO

    load: (rsName) ->
        rs = @resources[rsName]
        if rs
            rs.load()
        else
            alert 'no'

    load_a: (rsName, cbS, cbE, cbF) ->
        rs = @resources[rsName]
        if rs
            rs.load_a(cbS, cbE, cbF)
        else
            safeCall(cbE)
            safeCall(cbF)

    loads: (rsNames, cbS, cbE, cbF) ->
        resources = {}
        errors_cnt = 0
        success_cnt = 0
        finish_cnt = 0
        if rsNames.length == 0
            return safeCall(cbS, resources)

        for rsName in rsNames
            @load_a(rsName
                (rs) -> success_cnt++
                (rs) -> errors_cnt++
                (rs) ->
                    resources[rs.name] = rs

                    if ++finish_cnt >= rsNames.length
                        safeCall((if errors_cnt then cbE else cbS), resources)
                        safeCall(cbF, resources)
            )
    rqDo: (rsNames, f) ->
        @loads(rsNames,
        (resources) ->
            args = (resources[rsName].rqdata() for rsName in rsNames)

            safeApply(f, args)
        (resources) ->
            throw "error"
        )



safeCall = (f, args...) ->
    if TYPES.isFunction(f)
        f.apply(window, args)

safeApply = (f, args) ->
    if TYPES.isFunction(f)
        f.apply(window, args)


AJAX = {};
AJAX.J = (url, options) ->
    options ?= {}
    options.method ?= "GET"
    XHR = new XMLHttpRequest()
    XHR.id = new Date().getTime()
    XHR.open(options.method, url, options.async)

    cbsByState = {
        "2": options.onDataSend,
        "3": options.onDataRecieve,
        "4": options.onDataLoad,
        "4/200": [options.onSuccess, options.onFinish],
        "4/else": [options.onError, options.onFinish]
    }

    XHR.onreadystatechange = ->
        cbs = cbsByState[XHR.readyState] \
           || cbsByState[XHR.readyState+"/"+XHR.status] \
           || cbsByState[XHR.readyState+"/else"]

        if TYPES.isArray(cbs)
            safeCall(cb, XHR) for cb in cbs

        else
            safeCall(cbs, XHR)

    XHR.send(options.data || null)
    return XHR

for HTTP_METHOD in ["HEAD", "GET", "PUT", "POST", "DELETE"]
    ((HTTP_METHOD)->
        AJAX[HTTP_METHOD] = (url, options) ->
            options ?= {}
            options.method = HTTP_METHOD

            return AJAX.J(url, options)
        )(HTTP_METHOD)

AJAX.JL = (urls_data, coptions) ->
    coptions ?= {}
    coptions.method ?= "GET"
    results = {}
    data_cnt = 0;
    success_cnt = 0;
    errors_cnt = 0;
    for url_data in urls_data
        [url, options] = url_data
        ((url,options)->
            options ?= {}
            options.method ?= coptions.method
            originalFinishCB = options.onFinish
            options.onFinish = (XHR) ->
                results[url] = XHR
                if XHR.status == 200
                    success_cnt++
                else
                    errors_cnt++

                if ++data_cnt == urls_data.length
                    safeCall(coptions[if errors_cnt then 'onError' else 'onSuccess'], results)
                    safeCall(coptions.onFinish)

            return AJAX.J(url, options)
            )(url, options)



TYPES = {
    isArray: (obj) -> obj instanceof Array
    isFunction: (obj) -> obj instanceof Function
}


STORAGE = new Storage("jq", {
    "scripts": {
        "jquery":     ["/js/jquery-1.9.1.min.js", {"export": ["jQuery"]}],
        "jquery-ui":  ["/js/jquery-ui.js", {
            "export": ["jQuery"],
            "require": ["jquery", "jquery-ui-stylesheet"]
        }],
        "underscore": ["/js/underscore.js", {"export": ["_"]}],
    },

    "modules": {
        "aj": [{"AJAX": AJAX}, {"export": ["AJAX"]}]
    }

    "styles": {
        "NIHCSS": "/src/NIH.css",
        "jquery-ui-stylesheet": "/css/jquery-ui-1.10.3.custom.css"
    },

    "images": {
        "naked-ass": "/img/nakedass.png",
        "heavy": "/img/33.jpg"
    }
});


window.NIH = {
    "AJAX": AJAX,
    "STORAGE": STORAGE
};