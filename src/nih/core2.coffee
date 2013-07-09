class App
	constructor: (@name) ->
		@Modules = {}

	register: (module) ->
		@Modules[module.name] = module


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
		@Globals.window = @Globals
		@window = window

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

	likeNumber = (v) -> v? && /^\s*[-+]?\d+(\.\d+)?\s*$/.test(v)
	aISb = (obj, t) ->
		res = getType(obj) is t

		t = getType(t) unless typeof(t) is "string"

		if !res && window[t]
			res = obj instanceof window[t]

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


	exp({
		"lineNumber": likeNumber
		"is": aISb
		"type": getType
	})

	for typeName in ["Array", "Function", "Boolean", "String"]
		((typeName) ->
			exp("is#{typeName}", (obj) -> aISb(obj, typeName))
		)(typeName)
)

utils = new Module(app, "utils", ->
	imp("types as T")

	safeCallCtx = (f, ctx, args...) -> f.apply(ctx, args) if T.isFunction(f)
	safeCall = (f, args...) -> f.apply(window, args) if T.isFunction(f)
	safeApply = (f, args) -> f.apply(window, args) if T.isFunction(f)


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

	exp({
		"safeCall": safeCall
	})
)

ajax = new Module(app, "ajax", ->
	imp("types as T")
	imp("utils as U")

	J = (url, options={}) ->
		options.method ?= "GET"
		XHR = new XMLHttpRequest()
		XHR.id = new Date().getTime()
		XHR.open(options.method, url, options.async)

		cbsByState = {
			"2": options.onDataSend
			"3": options.onDataRecieve
			"4": options.onDataLoad
			"4/0": [options.onSuccess, options.onFinish] # from cache oO
			"4/200": [options.onSuccess, options.onFinish]
			"4/else": [options.onError, options.onFinish]
		}

		XHR.onreadystatechange = ->
			cbs = cbsByState[XHR.readyState] \
			   || cbsByState[XHR.readyState+"/"+XHR.status] \
			   || cbsByState[XHR.readyState+"/else"]

			if T.isArray(cbs)
				U.safeCall(cb, XHR) for cb in cbs

			else
				U.safeCall(cbs, XHR)

		XHR.send(options.data || null)
		return XHR

	exp({
		"J": J
	})
)

window.app = app