<template>
  <div class="nowbar q-pa-sm">
    <div class="row items-center no-wrap">
      <q-btn dense round flat icon="skip_previous" @click="prev" class="q-mr-md"/>
      <q-btn dense round color="primary" :icon="current?.item?.running ? 'pause' : 'play_arrow'" @click="toggle" class="q-mr-md"/>
      <q-btn dense round flat icon="skip_next" @click="next" class="q-mr-md"/>
      <div class="q-ml-md ellipsis">
        <div class="text-caption text-grey-7">Atual</div>
        <div class="text-body2 ellipsis">{{ current?.item?.title || '—' }}</div>
      </div>
      <q-space/>
      <div class="text-mono q-mr-md bigtime">{{ fmt(elapsed(current?.item)) }}</div>
      <q-btn dense round flat icon="tune" @click="$emit('open-panel')" />
    </div>
    <div class="row justify-end q-gutter-md q-mt-xs">
      <q-btn dense outline color="secondary" label="Início" @click="markStart"/>
      <q-btn dense outline color="negative" label="Fim" @click="markEnd"/>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, computed } from 'vue'
import { state, currentPointer, toggleStartStopCurrent, moveNext, movePrev, itemElapsedMs, markMeetingStartNow, markMeetingEndNow } from 'src/stores/timerStore'
import { formatMs } from 'src/utils/time'

const current = computed(() => currentPointer())
let t; const tick = ref(0)
onMounted(() => { t = setInterval(() => tick.value++, 250) })
onBeforeUnmount(() => { if (t) clearInterval(t) })

function fmt(ms) { return formatMs(ms || 0) }
function elapsed(item) { return item ? itemElapsedMs(item.id) + (tick.value&&0) : 0 }
function toggle() { toggleStartStopCurrent() }
function next() { moveNext() }
function prev() { movePrev() }
function markStart() { markMeetingStartNow() }
function markEnd() { markMeetingEndNow() }
</script>

<style scoped>
.nowbar { position: fixed; left: 0; right: 0; bottom: 0; background: #fff; border-top: 1px solid #e0e0e0; padding-bottom: 10px; }
.text-mono { font-family: monospace; min-width: 64px; text-align: right; }
.bigtime { font-size: 18px; }
</style>

