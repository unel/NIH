app = window.app
# TESTING: ModuleProvider
# app.do(->
# 	imp("rqs as R")
# 	mqj = new R.ModuleProvider("jq"
# 	"jQuery":
# 		"url": "/js/jquery-1.9.1.min.js"
# 		"exports": ["jQuery"]

# 	"jQueryUI":
# 		"url": "/js/jquery-ui.js"
# 		"deps": -> [new R.Requirement("jQuery")]
# 		"imports": [
# 			["jQuery", "jQuery"]
# 		]
# 		"exports": ["jQuery"]
# 	)

# 	mqj.provide(
# 		new R.Requirement("jQueryUI")
# 		(r, module) ->
# 			$ = module.Exports.jQuery
# 			$(->
# 				$("<div>oO</div>").dialog()
# 			)
# 	)
# )

# TESTING: TagBasedProviders
# app.do(->
# 	imp("rqs as R")
# 	images = new R.ImageProvider("xxx"
# 		"torvalds":
# 			"url": "/img/nakedass.png"
# 	)
# 	styles = new R.StyleProvider("xxx"
# 		"jQuery":
# 			"url": "/css/jquery-ui-1.10.3.custom.css"
# 			"deps": -> [
# 				new R.Requirement("jQuery-images")
# 			]
# 	)

# 	styles.provide(
# 		new R.Requirement("jQuery")
# 		(r, style) ->
# 			debugger
# 	)

# 	images.provide(
# 		new R.Requirement("torvalds")
# 		(r, img) ->
# 			document.getElementsByTagName('body')[0].appendChild(img)
# 	)
# )

# TESTING: ajax.J callbacks
# app.do(->
# 	imp("ajax", ["J"])

# 	J("/js/jquery-ui.js", {
# 		"onSuccess": [
# 			-> alert("ook!")
# 			-> alert("rly?")
# 		]
# 		"onError": [
# 			-> alert("nnooo")
# 		]
# 		"onDataLoad": -> alert('load')
# 		"onFinish": -> alert("f")
# 	})
# )

# TESTING: workers
app.do(->
	imp("workers", ["Worker as W"])
	window.app.w = new W("zoom")
)