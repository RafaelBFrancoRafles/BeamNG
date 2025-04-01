import { defineStore } from "pinia"
import { computed, ref, toRaw } from "vue"

export const FILTER_TYPES = {
  BLACKLIST: "blacklist",
  WHITELIST: "whitelist",
}

export const useMessageStore = defineStore("messages", () => {
  let db, ws

  const messages = ref([])
  const searchQuery = ref(null)
  const filters = ref({
    type: null,
    keywords: [],
  })

  const isAppConnected = ref(false)
  const isServerUp = ref(false)

  const filteredMessages = computed(() => {
    const filterFn = (msg) => {
      const nameMatch = msg.payload.name
        ?.toLowerCase()
        .includes(searchQuery.value)
      // const argsMatch = JSON.stringify(msg.payload.args)
      //   ?.toLowerCase()
      //   .includes(searchQuery.value)

      // return nameMatch || argsMatch
      return nameMatch
    }

    const sortFn = (msgA, msgB) =>
      new Date(msgB.timestamp) - new Date(msgA.timestamp)

    let msgs = messages.value.sort(sortFn)

    if (searchQuery.value) msgs = msgs.filter(filterFn)

    return msgs
  })

  const total = computed(() => messages.value.length)

  function resendMessage(message) {
    if (ws && ws.readyState === WebSocket.OPEN) {
      const requestMessage = {
        type: "devtools-request",
        timestamp: new Date().toISOString(),
        payload: toRaw(message.payload),
      }
      ws.send(JSON.stringify(requestMessage))
      console.log("devtools-request message sent to server", requestMessage)
    } else {
      console.warn("Websocket is not connected. Unable to send message.")
    }
  }

  function deleteAll() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("messagesDB", 1)

      request.onsuccess = (event) => {
        const db = event.target.result
        const transaction = db.transaction(["messages"], "readwrite")
        const objectStore = transaction.objectStore("messages")

        const clearRequest = objectStore.clear()

        clearRequest.onsuccess = () => {
          // console.log("All messages have been deleted.")
          messages.value = []
          resolve()
        }

        clearRequest.onerror = (event) => {
          // console.error("Error deleting messages:", event)
          reject(event)
        }
      }

      request.onerror = (event) => {
        // console.error("Error opening database:", event)
        reject(event)
      }
    })
  }

  async function init() {
    db = await openDatabase()
    messages.value = await getAllMessages()

    const existingFilters = await getFilters()
    filters.value = existingFilters

    connect()
  }

  // START Persistence
  function openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("messagesDB", 1)

      request.onupgradeneeded = (event) => {
        const db = event.target.result

        if (!db.objectStoreNames.contains("messages")) {
          db.createObjectStore("messages", {
            keyPath: "id",
            autoIncrement: true,
          })
        }

        if (!db.objectStoreNames.contains("filters")) {
          const filtersStore = db.createObjectStore("filters", {
            keyPath: "id",
          })
          filtersStore.add({ id: 1, type: null, keywords: [] })
        }

        // console.log("IndexedDB setup complete without timestamp index.")
      }

      request.onsuccess = (event) => {
        // console.log("Database opened successfully.")
        resolve(event.target.result)
      }

      request.onerror = (event) => {
        // console.error("Error opening database:", event)
        reject(event)
      }
    })
  }

  function addMessage(message) {
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["messages"], "readwrite")
      const objectStore = transaction.objectStore("messages")

      const request = objectStore.add(message) // Store the message directly

      request.onsuccess = () => {
        // console.log("Message added:", message)
        messages.value.push(message)
        resolve()
      }

      request.onerror = (event) => {
        // console.error("Error adding message:", event)
        reject(event)
      }
    })
  }

  function getAllMessages() {
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["messages"], "readonly")
      const objectStore = transaction.objectStore("messages")
      const messages = []

      objectStore.openCursor().onsuccess = (event) => {
        const cursor = event.target.result
        if (cursor) {
          messages.push(cursor.value)
          cursor.continue() // Continue to the next entry
        } else {
          // console.log("Fetched all messages:", messages)
          resolve(messages)
        }
      }

      transaction.onerror = (event) => {
        // console.error("Error fetching messages:", event)
        reject(event)
      }
    })
  }

  function updateFilters(filterType, keywords) {
    const updatedFilters = { id: 1, type: filterType, keywords }

    const transaction = db.transaction(["filters"], "readwrite")
    const objectStore = transaction.objectStore("filters")

    const request = objectStore.put(updatedFilters) // Update the filters with id = 1

    request.onsuccess = () => {
      filters.value.type = filterType
      filters.value.keywords = keywords
      // console.log("Filters updated:", updatedFilters)
    }

    request.onerror = (event) => {
      console.error("Error updating filters:", event)
    }
  }

  function getFilters() {
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(["filters"], "readonly")
      const objectStore = transaction.objectStore("filters")
      const request = objectStore.get(1) // Retrieve the filters with id = 1

      request.onsuccess = () => {
        if (request.result) {
          // console.log("Filters retrieved:", request.result)
          resolve(request.result)
        } else {
          // console.log("No filters found, using default values.")
          resolve({ type: null, keywords: [] }) // Default filters if not found
        }
      }

      request.onerror = (event) => {
        // console.error("Error retrieving filters:", event)
        reject(event)
      }
    })
  }

  // END Persistence

  // START Websocket
  async function onMessage(event) {
    // console.log("WS message received", event)
    const data = JSON.parse(event.data)
    const eventType = data.type
    if (eventType === "client_connection") {
      isAppConnected.value = data.connected
    } else if (eventType === "devtools-hook") {
      let allowMessage = true

      if (
        filters.value &&
        filters.value.type &&
        filters.value.keywords &&
        filters.value.keywords.length > 0
      ) {
        const inKeywords = filters.value.keywords.find(
          (x) => x.toLowerCase() === data.payload.name.toLowerCase()
        )
        if (filters.value.type === FILTER_TYPES.WHITELIST)
          allowMessage = inKeywords !== undefined
        else if (filters.value.type === FILTER_TYPES.BLACKLIST)
          allowMessage = inKeywords === undefined
      }

      if (allowMessage) await addMessage(data)
    }
  }

  function onClose(evt) {
    // console.log("WS closed")
    isServerUp.value = false
    if (!ws || ws.readyState == WebSocket.CLOSED) {
      // console.log("WS reconnecting in 1 second ...")
      setTimeout(function () {
        connect(ws)
      }, 1000)
    }
  }
  function onError(evt) {
    console.log("WS error", evt)
  }

  function onOpen() {
    // console.log("WS connected")
    isServerUp.value = true
  }

  function connect() {
    const host = import.meta.env.VITE_SERVER_HOST.trim()
    const port = import.meta.env.VITE_SERVER_PORT.trim()
    ws = new WebSocket(`ws://${host}:${port}`, "devtools-ui")
    try {
      ws.onclose = onClose
      ws.onerror = onError
      ws.onopen = onOpen
      ws.onmessage = onMessage
    } catch (exception) {
      console.log("Exception:", exception)
    }
  }
  // END Websocket

  return {
    messages: filteredMessages,
    filters,
    total,
    searchQuery,
    isServerUp,
    isAppConnected,
    init,
    deleteAll,
    resendMessage,
    updateFilters,
  }
})
