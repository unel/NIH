importScripts("/js/nih/core2.js")

app.do(->
	imp("ajax", ["J"])
	xhr = J("/js/nih/worker.js", {"sync": true})
	debugger
)