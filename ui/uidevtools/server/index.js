const WebSocket = require("ws")
const express = require("express")
const http = require("http")

const host = process.env.SERVER_HOST || "localhost"
const port = process.env.SERVER_PORT || 8085

const app = express()
app.use(express.static("server/public"))
app.get("/", (req, res) => {
  res.setHeader("Content-Type", "application/javascript")
  res.send(`
    const host = "${process.env.SERVER_HOST}"
    const port = "${process.env.SERVER_PORT}"

    console.log('Host and Port have been set to:', host, port)

    window.uiDevToolsConfig = { host, port }
  `)
})

const server = http.createServer(app)

const wss = new WebSocket.Server({ server })

wss.on("connection", function connection(ws) {
  console.log("client connected")
  notifyWsAppConnection(wss, ws)

  ws.on("message", function incoming(message) {
    const data = JSON.parse(message)
    console.log("message received", JSON.stringify(data))

    if (data.type === "devtools-request") {
      const appWs = getWsAppConnection(wss)
      if (appWs) appWs.send(JSON.stringify(data))
    } else {
      wss.clients.forEach(function each(client) {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify(data))
        }
      })
    }
  })

  ws.on("close", () => {
    if (ws.protocol === "devtools-client") notifyWsAppConnection(wss, ws)
    // console.log(`Client with subprotocol ${ws.protocol} disconnected`)
  })
})

function getWsAppConnection(wss) {
  if (!wss || !wss.clients) return undefined

  return [...wss.clients].find(
    (client) =>
      client.protocol === "devtools-client" &&
      client.readyState === WebSocket.OPEN
  )
}

function notifyWsAppConnection(wss, ws) {
  const messageType = "client_connection"
  const isAppConnected = getWsAppConnection(wss) !== undefined

  wss.clients.forEach(function each(client) {
    if (
      (client !== ws,
      client.protocol === "devtools-ui" && client.readyState === WebSocket.OPEN)
    ) {
      client.send(
        JSON.stringify({
          type: messageType,
          connected: isAppConnected,
        })
      )
    }
  })
}

server.listen(port, () => {
  console.log(`Server is running at http://${host}:${port}`)
})
