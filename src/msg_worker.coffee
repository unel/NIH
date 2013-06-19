connections = []
windows = []

msg = (port, message, data) ->
	port.postMessage({
		"id": 456
		"message": message
		"data": data
	})

notifyAll = (message, data) ->
	for port in connections
		msg(port, message, data)

messageProcessors =
	"get_id": (port, suffix) ->
		msg(port, "gen_id", genID(suffix))

	"register": (port, id) ->
		windows[id] = port
		notifyAll("new_window", id)

	"exit": (port, id) ->
		self.close()
		notifyAll("msg_core_exit")

	"message_to": (port, info) ->
		windowID = info.to
		if windows[windowID]
			msg(windows[windowID], info.message, info.data)
		else
			msg(port, "unknown windowID", windowID)

processMessage = (port, message, data) ->
	processor = messageProcessors[message]
	unless processor
		return msg(port, "unknown message", message)

	processor(port, data)

self.addEventListener('connect',
	(evt) ->
		port = evt.ports[0]
		connections.push(port)

		port.addEventListener('message',
			(evt) ->
				data = evt.data

				if data instanceof Object && data.message
					processMessage(port, data.message, data.data)
				else
					msg(port, "incorrect message", data)

			false
		)

		port.start()

		msg(port, "ready for this:", (name for name of messageProcessors))

	false
)


# utils

genID = (
	->
		IDS = {}
		(suffix) ->
			suffix ||= ""
			id = IDS[suffix] || 0

			IDS[suffix] = id+1;

			return suffix+id;
)()