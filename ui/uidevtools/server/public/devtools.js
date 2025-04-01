window.uidevRecorder_setup = function () {
  // console.log("devtools hook added")
  window.uiDevRecorder_reconnect()
}

window.uiDevRecorder_reconnect = function () {
  // console.log("uiDevRecorder_reconnect")
  const host = window.uiDevToolsConfig.host.trim()
  const port = window.uiDevToolsConfig.port.trim()
  window.uidevRecorderWS = new WebSocket(
    `ws://${host}:${port}`,
    "devtools-client"
  )
  try {
    window.uidevRecorderWS.onclose = function (evt) {
      // console.log("WS closed")
      if (!ws || ws.readyState == WebSocket.CLOSED) {
        console.log("WS reconnecting in 1 second ...")
        setTimeout(function () {
          window.uiDevRecorder_reconnect()
        }, 1000)
      }
    }
    window.uidevRecorderWS.onerror = function (evt) {
      console.log("WS error", evt)
    }

    window.uidevRecorderWS.onopen = function () {
      // console.log("WS connected")
      window.bridge.hooks.add("devtools-hook", (name, args) => {
        const data = {
          type: "devtools-hook",
          timestamp: new Date().toISOString(),
          payload: {
            name,
            args,
          },
        }
        window.uidevRecorderWS.send(JSON.stringify(data))
      })
    }
  } catch (exception) {
    console.log("Exception:", exception)
  }

  // Handle incoming messages and filter by type
  window.uidevRecorderWS.onmessage = function (event) {
    try {
      const message = JSON.parse(event.data)
      console.log("game message received", message)

      if (message.type === "devtools-request") {
        const event = message.payload
        console.log("event", event)
        window.bridge.events.emit(event.name, event.args)
      }
    } catch (error) {
      console.log("Error processing incoming message:", error)
    }
  }
}

window.addEventListener("load", (event) => {
  window.uidevRecorder_setup()
})
