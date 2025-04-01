<template>
  <div class="flex flex-col gap-2 h-full">
    <div v-if="filters.type" class="flex items-center">
      <span class="font-bold text-lg px-1">{{ filterTypeLabel }} keywords</span>
      <div
        v-for="keyword in filters.keywords"
        :key="keyword"
        class="badge badge-sm badge-primary mr-1"
      >
        {{ keyword }}
      </div>
    </div>

    <div class="flex justify-between">
      <div class="flex items-center gap-2 w-2/5">
        <label
          class="input input-bordered input-sm flex items-center gap-2 grow"
        >
          <input
            v-model="searchTerm"
            type="text"
            class="grow"
            placeholder="Search"
          />
          <i class="pi pi-search"></i>
        </label>
        <div>
          <div class="badge badge-md badge-outline badge-primary">
            {{ messages.length }}
          </div>
          /
          <div class="badge badge-md badge-neutral">{{ total }}</div>
        </div>

        <button
          class="btn btn-square btn-outline btn-sm"
          @click="openFiltersModal"
        >
          <i class="pi pi-filter"></i>
        </button>
      </div>

      <button class="btn btn-error btn-xs" @click="deleteAll">
        <i class="pi pi-trash"></i>
        Purge Logs
      </button>
    </div>

    <div class="overflow-y-auto">
      <table class="table table-pin-rows">
        <!-- head -->
        <thead>
          <tr>
            <th>Timestamp</th>
            <th>Name</th>
            <th></th>
          </tr>
        </thead>
        <tbody v-if="messages && messages.length > 0">
          <tr v-for="(message, index) of messages" :key="index">
            <th>
              {{ useDateFormat(message.timestamp, "DD-MM-YYYY HH:mm:ss.SSS") }}
            </th>
            <td>{{ message.payload.name }}</td>
            <td>
              <div class="flex gap-1">
                <div class="tooltip" data-tip="View Data">
                  <button
                    class="btn btn-circle btn-outline btn-sm"
                    @click="openModal(message)"
                  >
                    <i
                      class="pi pi-arrow-up-right-and-arrow-down-left-from-center"
                    ></i>
                  </button>
                </div>
                <div class="tooltip" data-tip="Copy">
                  <button
                    class="btn btn-circle btn-outline btn-sm"
                    :disabled="!isSupported"
                    @click="copyToClipboard(message)"
                  >
                    <i class="pi pi-clipboard"></i>
                  </button>
                </div>
                <div class="tooltip" data-tip="Download">
                  <button
                    class="btn btn-circle btn-outline btn-sm"
                    :disabled="isDownloading"
                    @click="downloadJson(message)"
                  >
                    <span
                      v-if="isDownloading"
                      class="loading loading-spinner"
                    ></span>
                    <i v-else class="pi pi-download"></i>
                  </button>
                </div>
                <div class="tooltip" data-tip="Resend">
                  <button
                    class="btn btn-circle btn-outline btn-sm"
                    :disabled="isDownloading"
                    @click="resendMessage(message)"
                  >
                    <span
                      v-if="isDownloading"
                      class="loading loading-spinner"
                    ></span>
                    <i v-else class="pi pi-send"></i>
                  </button>
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div v-if="!messages || messages.length === 0" class="text-center">
      No data available
    </div>
  </div>

  <dialog ref="modal" class="modal">
    <div class="modal-box max-w-5xl" v-if="modalContent">
      <form method="dialog">
        <button
          class="btn btn-sm absolute top-0 right-0 m-2 btn-circle btn-ghost"
        >
          <i class="pi pi-times"></i>
        </button>
      </form>
      <h3 class="text-lg font-bold">{{ modalContent.name }}</h3>
      <div>
        <VueJsonPretty
          v-if="modalContent.args"
          :data="modalContent.args"
          :deep="3"
          :height="500"
          show-icon
          virtual
          show-line-number
          show-length
        />
      </div>
    </div>
  </dialog>

  <dialog ref="filtersModal" class="modal">
    <div class="modal-box max-w-5xl">
      <form method="dialog">
        <button
          class="btn btn-sm absolute top-0 right-0 m-2 btn-circle btn-ghost"
        >
          <i class="pi pi-times"></i>
        </button>
      </form>
      <h3 class="text-lg font-bold">Filters</h3>
      <div class="flex gap-2">
        <div
          v-for="filterType of filterTypesModel"
          :key="filterType.value"
          class="form-control"
        >
          <label class="label cursor-pointer">
            <span class="label-text mr-2">{{ filterType.label }}</span>
            <input
              type="radio"
              name="radio-10"
              class="radio"
              :value="filterType.value"
              :checked="filterType.value == filtersModel.type"
              @change="filtersModel.type = filterType.value"
            />
          </label>
        </div>
      </div>
      <label
        v-if="filtersModel.type"
        class="input input-bordered flex items-center gap-2"
      >
        <input
          v-model="filtersModel.inputKeyword"
          type="text"
          class="grow"
          placeholder="Enter keyword then press enter"
          @keyup.enter="addKeyword"
        />
      </label>
      <div v-if="filtersModel.type" class="flex gap-1 py-2">
        <div
          v-for="keyword in filtersModel.keywords"
          :key="keyword"
          class="badge badge-md badge-primary"
        >
          <div class="flex items-baseline justify-center">
            {{ keyword }}
            <i
              class="pi pi-times text-xs cursor-pointer"
              @click="removeKeyword(keyword)"
            ></i>
          </div>
        </div>
        <div
          v-if="filtersModel.keywords.length === 0"
          role="alert"
          class="alert alert-warning"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            class="h-6 w-6 shrink-0 stroke-current"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            ></path>
          </svg>
          <span> No keywords added </span>
        </div>
      </div>
      <div class="modal-action">
        <form method="dialog">
          <button class="btn">Cancel</button>
        </form>
        <button
          class="btn btn-primary"
          @click="saveFilters"
          :disabled="!isFiltersValid"
        >
          Save
        </button>
      </div>
    </div>
  </dialog>
</template>

<script setup>
import { computed, ref, toRaw, watch } from "vue"
import { storeToRefs } from "pinia"
import { refDebounced, useClipboard, useDateFormat } from "@vueuse/core"
import VueJsonPretty from "vue-json-pretty"
import { useMessageStore, FILTER_TYPES } from "@/stores/messageStore"
import { useNotificationStore } from "@/stores/notificationStore"

const msgStore = useMessageStore()
const notifStore = useNotificationStore()
const { messages, total, filters } = storeToRefs(msgStore)
const { deleteAll } = msgStore
const resendMessage = async (message) => {
  await msgStore.resendMessage(message)
  notifStore.addNotification(
    "Event Resend Success",
    `${message.payload.name} event resent to game`
  )
}

const searchTerm = ref(null)
const searchDebounced = refDebounced(searchTerm, 500)
watch(searchDebounced, () => (msgStore.searchQuery = searchDebounced.value))

const source = ref("")
const { copy, copied, isSupported } = useClipboard({ source })
const copyToClipboard = (message) => copy(JSON.stringify(message.payload.args))

const filtersModal = ref(null)
const filtersModel = ref({
  inputKeyword: null,
  type: undefined,
  keywords: [],
})
const filterTypesModel = computed(() => [
  {
    label: "None",
    value: undefined,
  },
  {
    label: "Whitelist",
    value: FILTER_TYPES.WHITELIST,
  },
  {
    label: "Blacklist",
    value: FILTER_TYPES.BLACKLIST,
  },
])
const filterTypeLabel = computed(() => {
  const data = filterTypesModel.value.find(
    (x) => x.value === filters.value.type
  )
  return data.label
})
const isFiltersValid = computed(
  () =>
    !filtersModel.value.type ||
    (filtersModel.value.keywords && filtersModel.value.keywords.length > 0)
)
const openFiltersModal = () => {
  filtersModel.value.type = filters.value.type
  filtersModel.value.keywords = [...filters.value.keywords]
  filtersModal.value.showModal()
}
const addKeyword = () => {
  if (
    filtersModel.value.inputKeyword &&
    filtersModel.value.inputKeyword.trim().length > 0
  ) {
    filtersModel.value.keywords.push(filtersModel.value.inputKeyword)
    filtersModel.value.inputKeyword = null
  }
}
const removeKeyword = (keyword) => {
  const index = filtersModel.value.keywords.indexOf(keyword)
  if (index > -1) filtersModel.value.keywords.splice(index, 1)
}
const saveFilters = () => {
  msgStore.updateFilters(filtersModel.value.type, [
    ...filtersModel.value.keywords,
  ])
  filtersModal.value.close()
}

const modal = ref(null)
const modalContent = ref(null)
const openModal = (message) => {
  modalContent.value = message.payload
  modal.value.showModal()
}

const isDownloading = ref(false)
const downloadJson = (message) => {
  isDownloading.value = true

  const jsonString = JSON.stringify(message.payload.args, null, 2)
  const blob = new Blob([jsonString], { type: "application/json" })
  const link = document.createElement("a")

  link.href = URL.createObjectURL(blob)
  link.download = `${message.payload.name}.json` // Set the filename
  link.click()

  URL.revokeObjectURL(link.href)

  isDownloading.value = false
}

watch(
  () => copied.value,
  (value) => {
    if (value) notifStore.addNotification("Copied to clipboard")
  }
)
</script>

<style lang="scss" scoped></style>
