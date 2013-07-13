WND = this
class App
	constructor: (@name) ->
		@Modules = {}

	register: (module) ->
		@Modules[module.name] = module

	do: (expr) ->
		moduleName = "tmp"

		tmpModule = new Module(@, moduleName, expr)

		delete @Modules[moduleName]

class Module
	constructor: (@app, @name, init) ->
		self = this
		@app.register(self)
		@Globals = {}
		@Exports = {}
		@Builtins = {
			"imp": (moduleName, vars) ->
				info = moduleName.split(' as ')
				moduleName = info[0]
				moduleAlias = info[1] || moduleName
				module = self.app.Modules[moduleName]

				if vars
					for varName in vars
						info = varName.split(' as ')
						varName = info[0]
						alias = info[1] || varName
						self.Globals[alias] = module.Exports[varName]

				else
					self.Globals[moduleAlias] = module.Exports

			"exp": (vars, varValue) ->
				if vars instanceof Array
					for varName in vars
						self.Exports[varName] = self.Globals[varName]

				else if vars instanceof Object
					for varName,varValue of vars
						self.Exports[varName] = varValue

				else
					self.Exports[vars] = varValue
		}
		@window = WND

		@do(init)

	do: (expr) ->
		self = this;

		vars = {}
		vars[varName] = varValue for varName,varValue of @window
		if expr instanceof Function
			expr = "(#{expr.toString()})()"

		`
		with (this.Globals) {
		with (this.Builtins) {
			eval(expr);
		}
		}
		`

		for varName,varValue of @window when !vars.hasOwnProperty(varName)
			@Globals[varName] = varValue
			delete @window[varName]

app = new App("core")
types = new Module(app, "types", ->
	customs = {}

	iss =
		"Null": (v) -> v is null
		"Undefined": (v) -> v is undefined

	likeNumber = (v) -> v? && /^\s*[-+]?\d+(\.\d+)?\s*$/.test(v)
	aISb = (obj, t) ->
		res = getType(obj) is t

		t = getType(t) unless typeof(t) is "string"

		if !res && WND[t]
			res = obj instanceof WND[t]

		if !res && customs[t]
			res = obj instanceof customs[t]

		return res

	getType = (v) ->
		return if typeof(v) is "undefined"
		res = v.name
		if !res && v.constructor
			res = v.constructor.name

		if !res && v.prototype
			res = v.prototype.constructor.name

		return res


	exp(
		"likeNumber": likeNumber
		"is": aISb
		"type": getType
	)

	for typeName in ["Array", "Function", "Boolean", "String"]
		((typeName) ->
			iss[typeName] = (obj) -> aISb(obj, typeName)
			exp("is#{typeName}", iss[typeName])
		)(typeName)


	exp(
		"isEmpty"
		(v) -> iss["Undefined"](v) || iss["Null"](v) || (iss["String"](v) && v is "")
	)
)

utils = new Module(app, "utils", ->
	imp("types as T")

	safeCallCtx = (f, ctx, args...) -> f.apply(ctx, args) if T.isFunction(f)

	safeCall = (f, args...) ->
		if T.isArray(f)
			safeCall(fi, args) for fi in f

		else if T.isFunction(f)
			return f.apply(WND, args)


	safeApply = (f, args) -> f.apply(WND, args) if T.isFunction(f)
	repr = JSON.stringify

	Array.prototype.joine = (separator=', ') ->
		ret = []

		for e in this
			unless T.isEmpty(e)
				ret.push(e)

		return ret.join(separator)

	getField = (obj, path) ->
		return unless path
		ret = obj
		unless T.isArray(path)
			path = path.split(".")

		for field in path
			if ret && T.type(ret[field]) isnt "undefined"
				ret = ret[field]
			else
				return

		return ret

	mkTag = (tagName, attrs={}, style={}) ->
		specials =
			"text": (t, txt) -> t.innerText = txt
			"html": (t, html) -> t.innerHTML = html

		tag = document.createElement tagName

		for name,value of attrs
			if T.isBoolean(value) && value
				tag.setAttribute(name, "")

			else if T.isFunction(specials[name])
				specials[name](tag, value)

			else
				tag.setAttribute(name, value)

		for name,value of style
			tag.style[name] = value

		return tag

	exp(
		"repr": repr
		"pick":  (key) -> (obj) -> obj[key]
		"rpick": (obj) -> (key) -> obj[key]
		"safeCall": safeCall
		"mkTag": mkTag
	)
)

iter = new Module(app, "iter", ->
	imp("utils")

	processAsyncChain = (chain, processor, cb) ->
		ret = []
		total = chain.length
		utils.safeCall(cb, ret) unless total
		for idx,c in chain
			((idx,c) ->
				cCb = (type, data) ->
					ret[idx] = {
						"type": type,
						"data": data
					}
					total -= 1
					unless total
						utils.safeCall(cb, ret)

				processor(c, cCb)

			)(idx,c)

	processOrderedChain = (chain, processor, cb) ->
		ret = []
		idx = 0
		end = chain.length
		utils.safeCall(cb, ret) if idx == end

		iterator = () ->
			((c) ->
				cCb = (type, data) ->
					ret[idx] = {
						"type": type,
						"data": data
					}

					idx += 1
					if idx == end
						utils.safeCall(cb, ret)
					else
						iterator()

				processor(c, cCb) if c
			)(chain[idx])

		iterator()

	map = (list, f) -> ret = f(item) for item in list

	exp(
		"processAsyncChain": processAsyncChain
		"processOrderedChain": processOrderedChain
		"map": map
	)
)

ajax = new Module(app, "ajax", ->
	imp("types as T")
	imp("utils as U")

	J = (url, options={}) ->
		options.method ?= "GET"
		XHR = new XMLHttpRequest()
		XHR.id = new Date().getTime()
		XHR.open(options.method, url, options.async)

		cbsByState =
			"2": options.onDataSend
			"3": options.onDataRecieve
			"4": options.onDataLoad
			"4/0":    [options.onSuccess, options.onFinish] # from cache oO
			"4/200":  [options.onSuccess, options.onFinish]
			"4/else": [options.onError,   options.onFinish]

		XHR.onreadystatechange = ->
			U.safeCall([cbsByState[XHR.readyState],
						cbsByState[XHR.readyState+"/"+XHR.status] ||
						cbsByState[XHR.readyState+"/else"]])

		XHR.send(options.data || null)
		return XHR

	exp(
		"J": J
	)
)

workers = new Module(app, "workers", ->
	class TWorker
		constructor: (@url) ->

	class EWorker
		constructor: (@name,  @options={}) ->
			@worker = new (WND.Worker || TWorker)("/js/nih/worker.js")

	exp({
		"Worker": EWorker
	})
)

app.do(->
	imp("ajax", ["J"])
	imp("utils as U")
	imp("types as T")

	Module.fromURL = (app, name, url, imports=[], exports=[]) ->
		code = J(url).responseText

		for imp in imports
			if T.isArray(imp)
				moduleName = imp[0]
				vars = imp[1]
				vars = [vars] unless T.isArray(vars)
			else
				moduleName = imp

			impStr = "imp(#{[U.repr(moduleName), U.repr(vars)].joine()});\n"
			code = impStr + code
		module = new Module(app, name, code)
		module.Builtins.exp(exports)

		return module
)

rqs = new Module(app, "rqs", ->
	imp("utils as U")
	imp("types as T")
	imp("iter as I")

	class Requirement
		constructor: (@name) ->

	class Provider
		constructor: (@name, @Meta={}) ->
		provide: (req, cb) -> throw "need implementation"

	class ModuleProvider extends Provider
		provide: (req, cb) ->
			self = this
			meta = @Meta[req.name]

			success = (module) -> U.safeCall(cb, 1, module)
			fail    = (msg)    -> U.safeCall(cb, 0, msg)

			return fail("No meta for #{req.name}") unless meta

			deps = U.safeCall(meta.deps, req) || []

			I.processOrderedChain(
				deps
				(dReq, pCb) ->
					self.provide(
						dReq
						(rType, data) -> U.safeCall(pCb, rType, data)
					)

				(modulesInfo) ->
					success(Module.fromURL(
						app, req.name, meta.url, meta.imports, meta.exports
					))
			)

	class TagBasedProvider extends Provider
		constructor: (@name, @Meta={}) ->
			super(@name, @Meta)
			@tagsByURL = {}

		provide: (req, cb) ->
			self = this
			meta = @Meta[req.name]

			success = (tag) -> U.safeCall(cb, 1, tag.cloneNode(true))
			fail    = (msg) -> U.safeCall(cb, 0, msg)

			return fail("No meta for #{req.name}") unless meta

			url = meta.url
			tag = @tagsByURL[url]

			return success(tag) if tag

			@tagsByURL[url] = tag = U.mkTag(@tagName, @attrs)
			tag.setAttribute(@srcAttr, url)

			tag.onload = => success(tag)
			tag.onerror = => fail("loading error")

			document.getElementsByTagName('head')[0].appendChild(tag)


	class StyleProvider extends TagBasedProvider
		tagName: 'link'
		srcAttr: 'href'
		attrs: {
			"rel": "stylesheet"
		}

	class ImageProvider extends TagBasedProvider
		tagName: 'img'
		srcAttr: 'src'

	exp(
		"Requirement": Requirement
		"ModuleProvider": ModuleProvider
		"StyleProvider": StyleProvider
		"ImageProvider": ImageProvider
	)
)

WND.app = app
##########################################################################