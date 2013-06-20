######## TYPES ########
TYPES =
    likeNumber: (v) -> v? && /^\s*[-+]?\d+(\.\d+)?\s*$/.test(v)
    is: (obj, t) -> TYPES.type(obj) is t
    type: (v) ->
        res = null
        return if typeof(v) is "undefined"
        if !res && v.constructor
            res = v.constructor.name

        if !res && v.prototype
            res = v.prototype.constructor.name

        return res

for typeName in ["Array", "Function"]
    ((TYPES, typeName) ->
        TYPES["is"+typeName] = (obj) -> TYPES.is(obj, typeName)
    )(TYPES, typeName)

UTILS =
    safeCall: (f, args...) ->
        if TYPES.isFunction(f)
            f.apply(window, args)

    safeApply: (f, args) ->
        if TYPES.isFunction(f)
            f.apply(window, args)

    getField: (obj, path) ->
        return unless path
        ret = obj
        unless TYPES.isArray(path)
            path = path.split(".")

        for field in path
            if obj && obj.hasOwnProperty(field)
                obj = obj[field]
            else
                return

        return obj



######## AJAX ########
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
            UTILS.safeCall(cb, XHR) for cb in cbs

        else
            UTILS.safeCall(cbs, XHR)

    XHR.send(options.data || null)
    return XHR

for HTTP_METHOD in ["HEAD", "GET", "PUT", "POST", "DELETE"]
    ((HTTP_METHOD)->
        AJAX[HTTP_METHOD] = (url, options) ->
            options ?= {}
            options.method = HTTP_METHOD

            return AJAX.J(url, options)
        )(HTTP_METHOD)




######## RESOURCES ########
RS = {}
class RS.Resource
    constructor: (@name) ->
    load: -> ''
    rqdata: -> ''
    requirements: ->
        rqsInfo = @opt.require || []
        res = []
        for rqInfo in rqsInfo
            [rsName,rsVars] = rqInfo.split(':')
            rsVars = rsVars.split(';') if rsVars
            rs = @storage.resources[rsName] || throw "no req #{rsName}"
            res.push([rs, rsVars])

        return res

class RS.URLBasedResource extends RS.Resource
    constructor: (@name, @_url) ->
    url: ->
        return @_url

    data: -> @url()
    mkTag: ->
        elem = document.createElement @tagName
        elem.style.display = "none"

        attribs = @attribs || {}
        attribs[@attrName] = @url()
        attribs.id = attribs.id || "#{@name}#{new Date().getTime()}"

        for name, value of attribs
            elem.setAttribute(name, value)

        return elem

    load: (cbS, cbE, cbF) ->
        if @elem
            UTILS.safeCall(cbS, @)
            UTILS.safeCall(cbF, @)
            return

        @elem = @mkTag()

        @elem.onload = =>
            UTILS.safeCall(cbS, @)
            UTILS.safeCall(cbF, @)

        @elem.onerror = =>
            UTILS.safeCall(cbE, @)
            UTILS.safeCall(cbF, @)

        cont = document.getElementsByTagName('body')[0] or document.getElementsByTagName('head')[0]
        cont.appendChild(@elem)

    reload: ->
        @elem.remove()
        @elem = null
        @load()

    bind = (tag) ->
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

class RS.Image extends RS.URLBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'IMG'
        @attrName = 'src'

class RS.Style extends RS.URLBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'LINK'
        @attrName = 'href'
        @attribs =
            rel: "stylesheet"

class RS.Script extends RS.Resource
    constructor: (@name, @url, @opt) ->
        @opt ?= {}
        @module = new JS.LoadableModule(@name, @url)

    data: ->
        return undefined unless @opt.export
        if @opt.export.length > 1
            ret = {}
            for field in @opt.export
                ret[field] = @module.Globals[field]

        else if @opt.export.length == 1
            ret = @module.Globals[@opt.export[0]]

    load: (cbS, cbE, cbF) ->
        if @module.code
            UTILS.safeCall(cbS, @)
            UTILS.safeCall(cbF, @)
            return


        @module.load(
            => UTILS.safeCall(cbS, @)
            => UTILS.safeCall(cbE, @)
            => UTILS.safeCall(cbF, @)
        )

    init: ->
        return if @initialized

        rqsInfo = @requirements()
        for [rs,rsVars] in rqsInfo when TYPES.is(rs, "Script")
            @module.import(rs.module, rsVars)

        @module.init()
        @initialized = true

RS.Script.FromJSModule = (name, module, opt) ->
    rs = new RS.Script(name, "", opt)
    rs.module = module
    rs.module.code = "1"

    return rs

class RS.Storage
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
        @addResource(new RS.Script(name, url, opt))

    addImage: (name, url, opt) ->
        @addResource(new RS.Image(name, url, opt))

    addStyle: (name, url, opt) ->
        @addResource(new RS.Style(name, url, opt))

    addScriptFromModule: (name, module, opt) ->
        @addResource(RS.Script.FromJSModule(name, module, opt))

    rmResource: (rs) ->
        # TODO

    _load: (rsName, cbS, cbE, cbF) ->
        rs = @resources[rsName]
        if rs
            rs.load(cbS, cbE, cbF)
        else
            UTILS.safeCall(cbE)
            UTILS.safeCall(cbF)


    getRequirements: (rsNames) ->
        names = (rsName for rsName in rsNames)
        requirements = []
        seen = {}

        while(names.length)
            rsName = names.shift()
            unless seen[rsName]
                rsRequirements = (rqInfo.split(':')[0] for rqInfo in UTILS.getField(@resources, "#{rsName}.opt.require") || [])
                names = rsRequirements.concat(names)
                requirements.unshift(rsName)
                seen[rsName] = 1


        return requirements

    load: (rsNames, cbS, cbE, cbF) ->
        rsNames = [rsNames] unless TYPES.isArray(rsNames)
        rqNames = @getRequirements(rsNames)

        resources = {}
        errors_cnt = 0
        success_cnt = 0
        finish_cnt = 0
        if rqNames.length == 0
            return UTILS.safeCall(cbS, resources)

        for rsName in rqNames
            @_load(rsName
                (rs) -> success_cnt++
                (rs) -> errors_cnt++
                (rs) ->
                    resources[rs.name] = rs

                    if ++finish_cnt >= rqNames.length
                        UTILS.safeCall((if errors_cnt then cbE else cbS), resources)
                        UTILS.safeCall(cbF, resources)
            )

RS.rqDo = (storage, rsNames, f) ->
    rsNames = [rsNames] unless TYPES.isArray(rsNames)
    storage.load(rsNames,
        (resources) ->
            for rsName in rsNames when TYPES.is(resources[rsName], "Script")
                resources[rsName].init()

            args = (resources[rsName].data() for rsName in rsNames)
            UTILS.safeApply(f, args)

        -> throw "error"
    )


######## JS? ########
JS = {}
class JS.Module
    constructor: (@name, @Globals, @opt) ->
        @code = 1

    import: (module, vars) ->
        for varName in vars
            @Globals[varName] = module.Globals[varName]

class JS.LoadableModule extends JS.Module
    constructor: (@name, @url, @opt) ->
        @window = window
        @opt ?= {}
        @Globals = {}

    load: (cbS, cbE, cbF) ->
        if @code
            UTILS.safeCall(cbS)
            UTILS.safeCall(cbF)
            return

        AJAX.GET(@url, {
            async: true,
            onSuccess: (xhr) =>
                @code = xhr.responseText
                UTILS.safeCall(cbS)
                UTILS.safeCall(cbF)

            onError: (xhr) =>
                UTILS.safeCall(cbE)
                UTILS.safeCall(cbF)
        })

    absorbe: (f) ->
        oldKeys = {}
        oldKeys[key] = value for key,value of @window

        UTILS.safeCall(f)

        for key,value of @window when !oldKeys.hasOwnProperty(key)
            @Globals[key] = value
            delete @window[key] if key not in ['A'] # FIXIT


    init: () -> @do(@code)

    do: (code) ->
        ret = null
        _this = this
        @absorbe(
            `
            function(){
            with(_this.Globals){
                try{
                    ret = eval(code);

                } catch(err) {
                    throw err;

                }
            }
            }`
        )

        return ret




######## "EXPORT" SECTION ########
window.A = A = {
    RS: RS
    T: TYPES
    U: UTILS
}