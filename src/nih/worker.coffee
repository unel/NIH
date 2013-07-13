importScripts("/js/nih/core2.js")
self = this
@onmessage = (e) ->
	raw = e.data
	[msg, data] = [raw.title, raw.data]
	process(msg, data)

msg = (title, data) ->
	self.postMessage(
		"msg": title
		"data": data
	)

process = (msg, data) ->
	process = msgProcessors[msg]
	process(msg, data) if process

msgProcessors =
	"connect": -> msg("okay")

app.do(->
	imp("utils as U")
)