window.uidevRecorder_setup = function () {
  console.log("devtools hook added")
  window.uiDevRecorder_reconnect()
}

window.uiDevRecorder_reconnect = function () {
  console.log("uiDevRecorder_reconnect")
  console.log("process envs", {host, port})
  const host = import.meta.env.SERVER_HOST.trim()
  const port = import.meta.env.SERVER_PORT.trim()
  console.log("ws url", `ws://${host.trim()}:${port.trim()}`)
  window.uidevRecorderWS = new WebSocket(`ws://${host}:${port}`, "devtools-client")
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
}

window.addEventListener("load", (event) => {
  window.uidevRecorder_setup()
})
