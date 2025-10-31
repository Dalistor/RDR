<template>
  <q-dialog v-model="open" persistent maximized>
    <q-card class="q-pa-md">
      <div class="row items-center q-gutter-sm q-mb-sm">
        <div class="text-h6">Painel de controle</div>
        <q-space/>
        <q-btn flat icon="close" @click="close"/>
      </div>

      <div class="q-gutter-md">
        <div class="row q-gutter-md q-mb-md">
          <q-btn outline color="teal" label="+ Tesouros" @click="onAdd('treasures')" class="add-btn"/>
          <q-btn outline color="amber-9" label="+ Ministério" @click="onAdd('ministries')" class="add-btn"/>
          <q-btn outline color="red-8" label="+ Vida Cristã" @click="onAdd('christian_life')" class="add-btn"/>
        </div>

        <section v-for="section in sections" :key="section.key" class="q-mt-md">
          <div class="text-subtitle2 q-mb-xs" :class="section.color">{{ section.label }}</div>
          <q-list bordered separator>
            <template v-for="item in state[section.key]" :key="item.id">
              <q-item :class="{ 'current-item': isCurrent(item) }" class="item-row">
                <q-item-section avatar>
                  <q-icon v-if="isCurrent(item)" name="radio_button_checked" color="primary" size="sm"/>
                  <q-icon v-else name="radio_button_unchecked" color="grey-5" size="sm"/>
                </q-item-section>
                <q-item-section>
                  <q-input dense v-model="item.title" :class="{ 'current-input': isCurrent(item) }" />
                </q-item-section>
                <q-item-section side>
                  <div class="column q-gutter-xs">
                    <div class="row items-center q-gutter-sm">
                      <div class="text-mono time-display">{{ fmt(elapsed(item)) }}</div>
                      <q-btn size="sm" color="primary" :outline="!item.running" :label="item.running ? 'PARAR' : 'INICIAR'" @click="item.running ? stop(item) : start(item)" class="control-btn"/>
                      <q-btn size="sm" outline color="grey-7" label="ZERAR" @click="reset(item)" class="control-btn"/>
                    </div>
                    <div class="row items-center q-gutter-sm">
                      <q-btn size="sm" flat dense label="+ Subparte" @click="addSub(section.key, item.id)" class="action-btn"/>
                      <q-btn size="sm" flat dense color="negative" label="Remover" @click="remove(section.key, item.id)" class="action-btn"/>
                    </div>
                  </div>
                </q-item-section>
              </q-item>
              <q-item v-for="sub in (item.sub_parts||[])" :key="sub.id" class="q-pl-xl sub-item" :class="{ 'current-item': isCurrent(sub) }">
                <q-item-section avatar>
                  <q-icon v-if="isCurrent(sub)" name="radio_button_checked" color="primary" size="xs"/>
                  <q-icon v-else name="radio_button_unchecked" color="grey-5" size="xs"/>
                </q-item-section>
                <q-item-section>
                  <q-input dense v-model="sub.title" :class="{ 'current-input': isCurrent(sub) }" />
                </q-item-section>
                <q-item-section side>
                  <div class="column q-gutter-xs">
                    <div class="row items-center q-gutter-sm">
                      <div class="text-mono time-display">{{ fmt(elapsed(sub)) }}</div>
                      <q-btn size="sm" color="primary" :outline="!sub.running" :label="sub.running ? 'PARAR' : 'INICIAR'" @click="sub.running ? stop(sub) : start(sub)" class="control-btn"/>
                      <q-btn size="sm" outline color="grey-7" label="ZERAR" @click="reset(sub)" class="control-btn"/>
                    </div>
                    <div class="row">
                      <q-btn size="sm" flat dense color="negative" label="Remover" @click="remove(section.key, sub.id)" class="action-btn"/>
                    </div>
                  </div>
                </q-item-section>
              </q-item>
            </template>
          </q-list>
        </section>
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch, computed } from 'vue'
import { state, startTimer, stopTimer, resetTimer, addPart, addSubPart, removeItem, itemElapsedMs, currentPointer } from 'src/stores/timerStore'
import { formatMs } from 'src/utils/time'

const props = defineProps({
  modelValue: { type: Boolean, default: false }
})
const emit = defineEmits(['update:modelValue'])
const open = ref(props.modelValue)

watch(() => props.modelValue, v => open.value = v)
watch(open, v => emit('update:modelValue', v))

const sections = [
  { key: 'treasures', label: 'TESOUROS DA PALAVRA DE DEUS', color: 'text-teal-8' },
  { key: 'ministries', label: 'FAÇA SEU MELHOR NO MINISTÉRIO', color: 'text-amber-9' },
  { key: 'christian_life', label: 'NOSSA VIDA CRISTÃ', color: 'text-red-8' }
]

const current = computed(() => currentPointer())
const isCurrent = (item) => current.value?.item?.id === item.id

let tickerId;
const tick = ref(0)
onMounted(() => { tickerId = setInterval(() => tick.value++, 250) })
onBeforeUnmount(() => { if (tickerId) clearInterval(tickerId) })

function fmt(ms) { return formatMs(ms) }
function elapsed(item) { /* usa tick para re-renderizar */ return itemElapsedMs(item.id) + (tick.value&&0) }

function start(item) { startTimer(item.id) }
function stop(item) { stopTimer(item.id) }
function reset(item) { resetTimer(item.id) }
function onAdd(sectionKey) { addPart(sectionKey) }
function addSub(sectionKey, parentId) { addSubPart(sectionKey, parentId) }
function remove(sectionKey, id) { removeItem(sectionKey, id) }
function close() { open.value = false }
</script>

<style scoped>
.text-mono { font-family: monospace; }
.time-display { min-width: 70px; text-align: right; font-weight: 600; }
.control-btn { min-width: 80px; }
.action-btn { min-width: 70px; }
.current-item {
  background-color: rgba(25, 118, 210, 0.08) !important;
  border-left: 4px solid #1976d2;
  border-radius: 4px;
  margin: 4px 0;
}
.current-input :deep(.q-field__control) {
  background-color: rgba(25, 118, 210, 0.1);
  font-weight: 600;
}
.item-row {
  padding: 12px 8px;
  margin: 2px 0;
}
.sub-item {
  padding: 8px 8px;
  margin-left: 16px;
  background-color: rgba(0, 0, 0, 0.02);
}
.add-btn {
  padding: 8px 16px;
}
</style>

