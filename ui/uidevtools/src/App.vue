<template>
  <div class="flex flex-col h-full w-full">
    <div class="navbar bg-base-100">
      <div class="flex-1">
        <a class="btn btn-ghost text-xl">UIDevTools</a>
      </div>
      <div class="flex gap-2">
        <!-- websocket connection status-->
        <div class="badge badge-outline">
          <span>Game</span>
          <i
            class="pi pi-circle-fill ms-1"
            :class="{
              'text-green-500': isAppConnected,
              'text-red-500': !isAppConnected,
            }"
          ></i>
        </div>
        <div class="badge badge-outline">
          <span>Server</span>
          <i
            class="pi pi-circle-fill ms-1"
            :class="{
              'text-green-500': isServerUp,
              'text-red-500': !isServerUp,
            }"
          ></i>
        </div>
      </div>
    </div>
    <div class="grow p-4 overflow-hidden">
      <router-view />
    </div>
  </div>

  <div class="toast toast-top toast-end z-50">
    <div v-for="notification in notifications" class="flex flex-col items-start alert alert-info text-white">
      <span class="text-lg font-bold">{{ notification.title }}</span>
      <span class="text-md font-semibold">{{ notification.description }}</span>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from "vue"
import { storeToRefs } from "pinia"
import { useMessageStore } from "@/stores/messageStore"
import { useNotificationStore } from "@/stores/notificationStore"

const msgStore = useMessageStore()
const { isServerUp, isAppConnected } = storeToRefs(msgStore)

const notifStore = useNotificationStore()
const { notifications } = storeToRefs(notifStore)

onMounted(async () => {
  await msgStore.init()
})
</script>

<style scoped></style>
