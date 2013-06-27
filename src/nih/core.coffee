######## TYPES ########
TYPES =
    likeNumber: (v) -> v? && /^\s*[-+]?\d+(\.\d+)?\s*$/.test(v)
    is: (obj, t) ->
        res = TYPES.type(obj) is t

        t = TYPES.type(t) unless typeof(t) is "string"

        if !res && window[t]
            res = obj instanceof window[t]

        if !res && TYPES.customs[t]
            res = obj instanceof TYPES.customs[t]

        return res

    type: (v) ->
        return if typeof(v) is "undefined"
        res = v.name
        if !res && v.constructor
            res = v.constructor.name

        if !res && v.prototype
            res = v.prototype.constructor.name

        return res

    customs: {}

for typeName in ["Array", "Function", "Boolean", "String"]
    ((TYPES, typeName) ->
        TYPES["is"+typeName] = (obj) -> TYPES.is(obj, typeName)
    )(TYPES, typeName)

UTILS =
    safeCallCtx: (f, ctx, args...) -> f.apply(ctx, args) if TYPES.isFunction(f)
    safeCall: (f, args...) -> f.apply(window, args) if TYPES.isFunction(f)
    safeApply: (f, args) -> f.apply(window, args) if TYPES.isFunction(f)


    getField: (obj, path) ->
        return unless path
        ret = obj
        unless TYPES.isArray(path)
            path = path.split(".")

        for field in path
            if ret && TYPES.type(ret[field]) isnt "undefined"
                ret = ret[field]
            else
                return

        return ret

######## TAGS ########
TAGS = {}
TAGS.mkTag = (tagName, attribs={}, style={}) ->
    tag = document.createElement tagName
    for name,value of attribs
        if TYPES.isBoolean(value) && value
            tag.setAttribute(name, "")
        else
            tag.setAttribute(name, value)

    for name,value of style
        tag.style[name] = value

    return tag


######## AJAX ########
AJAX = {};
AJAX.J = (url, options) ->
    options ?= {}
    options.method ?= "GET"
    XHR = new XMLHttpRequest()
    XHR.id = new Date().getTime()
    XHR.open(options.method, url, options.async)

    cbsByState = {
        "2": options.onDataSend
        "3": options.onDataRecieve
        "4": options.onDataLoad
        "4/200": [options.onSuccess, options.onFinish]
        "4/0": [options.onSuccess, options.onFinish] # from cache oO
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
RS.Resource.fromCache = ->

class RS.TagBasedResource extends RS.Resource
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

        cont = document.getElementsByTagName('body')[0] \
            or document.getElementsByTagName('head')[0]
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

class RS.Image extends RS.TagBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'IMG'
        @attrName = 'src'

class RS.Style extends RS.TagBasedResource
    constructor: (@name, @_url) ->
        @tagName = 'LINK'
        @attrName = 'href'
        @attribs =
            rel: "stylesheet"

class RS.Script extends RS.Resource
    constructor: (@name, @url, @opt) ->
        @opt ?= {}
        @module = new JS.LoadableModule(@name, @url)

    cacheData: ->
        return {
            "rsClass": "Script"
            "name": @name
            "opt": @opt
            "code": @module.code
        }

    data: ->
        return undefined unless @opt.export
        if @opt.export.length > 1
            ret = {}
            for field in @opt.export
                ret[field] = @module.Globals[field]

        else if @opt.export.length == 1
            ret = @module.Globals[@opt.export[0]]

        return ret

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
            rs.module.init()
            @module.import(rs.module, rsVars)

        @module.init()
        @initialized = true

RS.Script.FromJSModule = (name, module, opt) ->
    rs = new RS.Script(name, "", opt)
    rs.module = module
    rs.module.code ?= "1"

    return rs

RS.Script.fromCache = (data) ->
    module = new JS.LoadableModule(data.name, "")
    module.code = data.code
    RS.Script.FromJSModule(data.name, module, data.opt)


class RS.ExternalScript extends RS.Script
    constructor: (@name, @url, @opt={}) ->
        @window = window

        @module = new JS.Module(@name, {}, {window: @window})
        @module.code = 0


        # document.getElementsByTagName('head')[0].appendChild(@ifr)

    import: (module, vars) ->
        for varName in vars
            @window[varName] = @module.Globals[varName] = module.Globals[varName]

    load: (cbS, cbE, cbF) ->
        if @module.code
            UTILS.safeCall(cbS, @)
            UTILS.safeCall(cbF, @)
            return

        # 1. import requirements to iframe window
        # 2. add script tag
        # 3. absorbe
        rqsInfo = @opt.require || []

        rqsInfo = (rqInfo.split(':') for rqInfo in rqsInfo)
        rqNames = (rqName for [rqName,rqVars] in rqsInfo)

        @storage.load(rqNames,
            (resources) =>
                for [rsName,rsVars] in rqsInfo when TYPES.is(resources[rsName], "Script")
                    resources[rsName].init()
                    @import(resources[rsName].module, rsVars.split(';'))

                @tag = TAGS.mkTag('script', {"src": @url})

                @tag.onload = =>
                    @module._postAbsorbe()
                    @module.code = 1
                    UTILS.safeCall(cbS, @)
                    UTILS.safeCall(cbF, @)

                @tag.onerror = =>
                    UTILS.safeCall(cbE, @)
                    UTILS.safeCall(cbF, @)

                @module._preAbsorbe()
                document.getElementsByTagName('head')[0].appendChild(@tag)

            cbE, cbF
        )

    init: -> # pass


class RS.SimpleCache
    constructor: (@name) ->
        @key = "RS.SimpleCache.data."+@name
        @cacheData = sessionStorage[@key]
        @cacheData = JSON.parse(@cacheData) if @cacheData

    load: (cbS, cbE, cbF) ->
        if @cacheData
            rsClass = @cacheData.rsClass
            rs = RS[@cacheData.rsClass].fromCache(@cacheData)
            rs.storage = @storage

            if rs
                UTILS.safeCall(cbS, rs)
                UTILS.safeCall(cbF, rs)
            else
                UTILS.safeCall(cbS, @)
                UTILS.safeCall(cbF, @)

        else
            UTILS.safeCall(cbE, @)
            UTILS.safeCall(cbF, @)

    rsCopy: (rs) ->
        sessionStorage[@key] = JSON.stringify(rs.cacheData())

class RS.FSCache
    constructor: (@name, @rsClass) ->
        @key = "/RS/FSCache/#{@name}"

    load: (cbS, cbE, cbF) ->
        RS.rqDo(RS.coreStorage, [RS.P.FS(1024)]
            (FS) =>
                FS.read(@key, {"method": "readAsDataURL"},
                    (url) =>
                        rs = new RS[@rsClass](@name, url)
                        if rs
                            UTILS.safeCall(cbS, rs)
                            UTILS.safeCall(cbF, rs)
                        else
                            UTILS.safeCall(cbE, rs)
                            UTILS.safeCall(cbF, rs)
                    (fe) =>
                        console.warn("xx", fe)
                        UTILS.safeCall(cbE, fe)
                        UTILS.safeCall(cbF, fe)
                )
            =>
                UTILS.safeCall(cbE)
                UTILS.safeCall(cbF)
        )

    rsCopy: (rs) ->

        img = rs.elem
        c = A.TAGS.mkTag('canvas')
        c.width = img.width
        c.height = img.height
        ctx = c.getContext('2d')
        ctx.drawImage(img, 0, 0)

        dataURL = c.toDataURL("image/jpeg")
        # console.log(rs, dataURL)

        RS.rqDo(RS.coreStorage, [RS.P.FS(1024)],
            (FS) =>
                data = FS.dataURLtoBlob(dataURL, "image/jpeg")
                console.log("data", data)#, dataURL)
                FS.write(@key, {
                        "data": data
                    },
                    => console.log("rsCopy success")

                    (fe) =>
                        console.error("rsCopy failed", fe)
                        if fe.code is fe.NOT_FOUND_ERR
                            FS.mkFile(@key
                                =>
                                    FS.write(@key, {"data": data},
                                        => console.log("rsCopy ok")
                                        => console.error("rsCopy err", fe)
                                    )
                                (fe) =>
                                    FS.rmFile(@key)
                                    console.error("rsCopy err", fe)
                            )
                )
        )
        # ... ? ...
        # debugger





class RS.Linked extends RS.Resource
    constructor: (@name, @resources..., @opt) ->

    load: (cbS, cbE, cbF) ->
        for rs in @resources
            rs.storage = @storage
            rs.opt = @opt
            rs.name ||= @name

        @_load({
            "idx": 0
        }, cbS, cbE, cbF)

    _load: (state, cbS, cbE, cbF) ->
        rs = @resources[state.idx || 0]
        unless rs
            UTILS.safeCall(cbE, @)
            UTILS.safeCall(cbF, @)
            return

        rs.load(
            (rs) =>
                # notify prevous about me
                @notify(rs, state)
                UTILS.safeCall(cbS, rs)
                UTILS.safeCall(cbF, rs)

            (rs) =>
                # try next
                state.idx++
                @_load(state, cbS, cbE, cbF)
        )

    notify: (rs, state) ->
        return unless state.idx
        for lrs in @resources[0..state.idx]
            UTILS.safeCallCtx(lrs.rsCopy, lrs, rs)



class RS.Storage
    constructor: (@name, resourcesInfo) ->
        @resources = {}

        rsMethods = {
            "scripts:c": "addCachedScript"
            "scripts": "addScript"

            "styles": "addStyle"

            "images:c": "addCachedImage"
            "images": "addImage"
            "modules": "addScriptFromModule"
        }
        if resourcesInfo
            if TYPES.isString(resourcesInfo)
                xhr = AJAX.GET(resourcesInfo)
                resourcesInfo = JSON.parse(xhr.responseText)
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

    addCachedResource: (rs, opt) ->
        @addResource(new RS.Linked(rs.name, new RS.SimpleCache(""), rs, opt))

    addFSCachedResource: (rs, opt) ->
        @addResource(new RS.Linked(rs.name, new RS.FSCache(rs.name, opt.rsClass), rs, opt))

    addCachedScript: (name, url, opt) ->
        @addCachedResource(new RS.Script(name, url), opt)

    addImage: (name, url, opt) ->
        @addResource(new RS.Image(name, url, opt))

    addCachedImage: (name, url, opt) ->
        opt ?= {}
        opt.rsClass = opt.rsClass || "Image";
        @addFSCachedResource(new RS.Image(name, url), opt)

    addStyle: (name, url, opt) ->
        @addResource(new RS.Style(name, url, opt))

    addScriptFromModule: (name, module, opt) ->
        @addResource(RS.Script.FromJSModule(name, module, opt))

    rmResource: (rs) ->
        # TODO

    _load: (rsName, cbS, cbE, cbF) ->
        rs = if TYPES.isString(rsName) then @resources[rsName] else rsName
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


RS.P = {} # parametrized
class RS.Custom extends RS.Resource
    constructor: (@name, @loader, @dataResolver, @opt) ->

    load: (cbS, cbE, cbF) => @loader(cbS, cbE, cbF)

    data: -> @dataResolver()

RS.P.FS = (size) ->
    return new RS.Custom(
        "fs_#{size}"
        (cbS, cbE, cbF) ->
            RS.rqDo(RS.coreStorage, ["nih.files", "nih.core"]
            (FS, A) =>
                new FS.FS(size,
                    (FS) =>
                        @FS = FS
                        A.UTILS.safeCall(cbS, @)
                        A.UTILS.safeCall(cbF, @)

                    (fe) =>
                        A.UTILS.safeCall(cbE, fe)
                        A.UTILS.safeCall(cbF, fe)

                )
            =>
                UTILS.safeCall(cbE)
                UTILS.safeCall(cbF)
            )
        -> @FS
    )



RS.rqDo = (storage, rsNames, f) ->
    rsNames = [rsNames] unless TYPES.isArray(rsNames)
    storage.load(rsNames,
        (resources) ->
            args = []
            for rsName in rsNames
                rs = if TYPES.isString(rsName) then resources[rsName] else resources[rsName.name]
                rs.init() if TYPES.is(rs, "Script")
                args.push(
                    UTILS.safeCallCtx(UTILS.getField(rs, 'data'), rs)
                )

            UTILS.safeApply(f, args)

        -> throw "error"
    )




######## JS? ########
JS = {}
class JS.Module
    constructor: (@name, @Globals={}, @opt={}) ->
        @code = 1
        @window = opt.window || window

    import: (module, vars) ->
        for varName in vars
            @Globals[varName] = module.Globals[varName]

    _preAbsorbe: ->
        @oldKeys = {}
        @oldKeys[key] = value for key,value of @window

    _postAbsorbe: ->
        for key,value of @window when !@oldKeys.hasOwnProperty(key)
            @Globals[key] = value
            delete @window[key] if key not in ['A'] # FIXIT

    absorbe: (f) ->
        @_preAbsorbe()
        UTILS.safeCall(f)
        @_postAbsorbe()

    init: () -> # pass

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
            async: true
            onSuccess: (xhr) =>
                @code = xhr.responseText
                UTILS.safeCall(cbS)
                UTILS.safeCall(cbF)

            onError: (xhr) =>
                @code = xhr.responseText
                UTILS.safeCall(cbE)
                UTILS.safeCall(cbF)
        })




    init: -> @do(@code)

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
methodNames = ['requestFileSystem', 'storageInfo']
vendorPrefixes = ['webkit'];
for methodName in methodNames
    methodNameS = methodName[0].toUpperCase() + methodName.substring(1)
    for vendorPrefix in vendorPrefixes
        window[methodName] ?= window[vendorPrefix+methodNameS]


window.A = A = {
    AJAX: AJAX
    RS: RS
    T: TYPES
    TAGS: TAGS
    UTILS: UTILS
}

RS.coreStorage = new RS.Storage("core", {
    "modules":
        "nih.core": [
            new JS.Module("nih.core", {
                "A": A
            }, {})
            {"export": "A"}
        ]

    "scripts":
        "nih.files": [
            "/js/nih/fs.js"
            {
                "export": ["FILES"]
                "require": ["nih.core:A"]
            }
        ]
});



TYPES.customs.Script = RS.Script
TYPES.customs.ExternalScript = RS.ExternalScript




######## TEST SECTION ########
# RS.rqDo(RS.coreStorage, [RS.P.FS(3000)]
#     (FS) ->
#         console.log('FS', FS)
# )