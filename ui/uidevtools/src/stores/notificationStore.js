import { defineStore } from "pinia"
import { ref } from "vue"
export const useNotificationStore = defineStore("notifications", () => {
  const notifications = ref([])

  function addNotification(
    title,
    description,
    config = { type: "info", timeout: 2000 }
  ) {
    const notification = { title, description, config }
    notifications.value.push(notification)

    setTimeout(() => {
      removeNotification(notification)
    }, config.timeout || 3000)
  }

  function removeNotification(notification) {
    const index = notifications.value.indexOf(notification)
    if (index > -1) {
      notifications.value.splice(index, 1)
    }
  }

  return { notifications, addNotification, removeNotification }
})
