<template>
  <div class="report" ref="reportRoot">
    <h4 class="center report-title">Relatório da reunião</h4>

    <div class="meta">
      <div>Início da reunião: {{ state.meta.initial_time || '--:--' }}</div>
      <div class="line">
        <span class="t" v-if="editId!=='opening_comments'" @click.stop="beginEdit(state.opening_comments)" :class="{ 'highlight-green': highlightedId === 'opening_comments' }">Comentários iniciais:</span>
        <input v-else v-model="editText" @keyup.enter="commitEdit(state.opening_comments)" @blur="commitEdit(state.opening_comments)" class="edit" />
        <span class="v" @dblclick.stop="manualTime(state.opening_comments)">{{ fmt(itemElapsed(state.opening_comments)) }}</span>
      </div>
    </div>

    <section class="sec" v-if="hasData">
      <div class="sec-header teal" @click="sectionActions('treasures')">
        <img :src="icons.treasures" alt="" class="sec-icon" />
        <span class="name">TESOUROS DA PALAVRA DE DEUS</span>
      </div>
      <template v-if="!loading">
      <div v-for="(p,idx) in state.treasures" :key="p.id" class="line">
        <div class="line-main">
          <span class="t" v-if="editId!==p.id" @click.stop="beginEdit(p)" :class="{ 'highlight-green': highlightedId === p.id }">{{ p.title }}</span>
          <input v-else v-model="editText" @keyup.enter="commitEdit(p)" @blur="commitEdit(p)" class="edit" />
          <span class="v" @dblclick.stop="manualTime(p)">{{ fmt(itemElapsed(p)) }}</span>
        </div>
        <div v-if="p.sub_parts?.length" class="sub">
          <div v-for="sp in p.sub_parts" :key="sp.id" class="sline">
            <span class="t" v-if="editId!==sp.id" @click.stop="beginEdit(sp)" :class="{ 'highlight-green': highlightedId === sp.id }">• {{ sp.title }}:</span>
            <span v-else class="s-edit">
              • <input v-model="editText" @keyup.enter="commitEdit(sp)" @blur="commitEdit(sp)" class="edit" />
            </span>
            <span class="v" @dblclick.stop="manualTime(sp)">{{ fmt(itemElapsed(sp)) }}</span>
          </div>
        </div>
      </div>
      </template>
      <template v-else>
        <q-skeleton v-for="i in 3" :key="'t-skel-'+i" type="text" class="q-my-xs" />
        <q-skeleton v-for="i in 3" :key="'t-sskel-'+i" type="text" class="q-ml-md q-my-xs" />
      </template>
    </section>

    <section class="sec" v-if="hasData">
      <div class="sec-header amber" @click="sectionActions('ministries')">
        <img :src="icons.ministry" alt="" class="sec-icon" />
        <span class="name">FAÇA SEU MELHOR NO MINISTÉRIO</span>
      </div>
      <template v-if="!loading">
      <div v-for="(p,idx) in state.ministries" :key="p.id" class="line">
        <div class="line-main">
          <span class="t" v-if="editId!==p.id" @click.stop="beginEdit(p)" :class="{ 'highlight-green': highlightedId === p.id }">{{ p.title }}</span>
          <input v-else v-model="editText" @keyup.enter="commitEdit(p)" @blur="commitEdit(p)" class="edit" />
          <span class="v" @dblclick.stop="manualTime(p)">{{ fmt(itemElapsed(p)) }}</span>
        </div>
        <div v-if="p.sub_parts?.length" class="sub">
          <div v-for="sp in p.sub_parts" :key="sp.id" class="sline">
            <span class="t" v-if="editId!==sp.id" @click.stop="beginEdit(sp)" :class="{ 'highlight-green': highlightedId === sp.id }">• {{ sp.title }}:</span>
            <span v-else class="s-edit">• <input v-model="editText" @keyup.enter="commitEdit(sp)" @blur="commitEdit(sp)" class="edit" /></span>
            <span class="v" @dblclick.stop="manualTime(sp)">{{ fmt(itemElapsed(sp)) }}</span>
          </div>
        </div>
      </div>
      </template>
      <template v-else>
        <q-skeleton v-for="i in 4" :key="'m-skel-'+i" type="text" class="q-my-xs" />
        <q-skeleton v-for="i in 6" :key="'m-sskel-'+i" type="text" class="q-ml-md q-my-xs" />
      </template>
    </section>

    <section class="sec" v-if="hasData">
      <div class="sec-header red" @click="sectionActions('christian_life')">
        <img :src="icons.christian" alt="" class="sec-icon" />
        <span class="name">NOSSA VIDA CRISTÃ</span>
      </div>
<div class="line"><span class="t">Presidente:</span> <span class="v">{{ fmt(0) }}</span></div>
      <template v-if="!loading">
      <div v-for="(p,idx) in state.christian_life" :key="p.id" class="line">
        <div class="line-main">
          <span class="t" v-if="editId!==p.id" @click.stop="beginEdit(p)" :class="{ 'highlight-green': highlightedId === p.id }">{{ p.title }}</span>
          <input v-else v-model="editText" @keyup.enter="commitEdit(p)" @blur="commitEdit(p)" class="edit" />
          <span class="v" @dblclick.stop="manualTime(p)">{{ fmt(itemElapsed(p)) }}</span>
        </div>
        <div v-if="p.sub_parts?.length" class="sub">
          <div v-for="sp in p.sub_parts" :key="sp.id" class="sline">
            <span class="t" v-if="editId!==sp.id" @click.stop="beginEdit(sp)" :class="{ 'highlight-green': highlightedId === sp.id }">• {{ sp.title }}:</span>
            <span v-else class="s-edit">• <input v-model="editText" @keyup.enter="commitEdit(sp)" @blur="commitEdit(sp)" class="edit" /></span>
            <span class="v" @dblclick.stop="manualTime(sp)">{{ fmt(itemElapsed(sp)) }}</span>
          </div>
        </div>
      </div>
      </template>
      <template v-else>
        <q-skeleton v-for="i in 3" :key="'c-skel-'+i" type="text" class="q-my-xs" />
        <q-skeleton v-for="i in 3" :key="'c-sskel-'+i" type="text" class="q-ml-md q-my-xs" />
      </template>
    </section>

    <div v-if="hasData" class="meta bottom">
      <div class="line">
        <span class="t" v-if="editId!=='final_comments'" @click.stop="beginEdit(state.final_comments)" :class="{ 'highlight-green': highlightedId === 'final_comments' }">Comentários finais:</span>
        <input v-else v-model="editText" @keyup.enter="commitEdit(state.final_comments)" @blur="commitEdit(state.final_comments)" class="edit" />
        <span class="v" @dblclick.stop="manualTime(state.final_comments)">{{ fmt(itemElapsed(state.final_comments)) }}</span>
      </div>
      <div>Fim da reunião: {{ state.meta.final_time || '--:--' }}</div>
    </div>
    <div v-else class="empty">
      Nenhum relatório disponível ainda. Toque no botão de timer para abrir o painel e iniciar.
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, computed, nextTick, watch } from 'vue'
import { useQuasar } from 'quasar'
import { state, itemElapsedMs, sectionTotalMs, setTitle, setManualTime, addPart, addSubPart, removeItem, currentPointer } from 'src/stores/timerStore'
import { formatMs, parseMmSs } from 'src/utils/time'

const $q = useQuasar()

const props = defineProps({ loading: { type: Boolean, default: false } })

const reportRoot = ref(null)
const editId = ref(null)
const editText = ref('')
const editInput = ref(null)
const highlightedId = ref(null)
let highlightTimeout = null
const icons = {
  treasures: new URL('../assets/treasures.png', import.meta.url).href,
  ministry: new URL('../assets/ministry.png', import.meta.url).href,
  christian: new URL('../assets/christian_file.png', import.meta.url).href
}

let tickerId; const tick = ref(0)
const currentPtr = computed(() => currentPointer())

// Watch para detectar mudanças no ponteiro e destacar
watch(currentPtr, (newPtr, oldPtr) => {
  if (!newPtr || !newPtr.item) return
  if (!oldPtr || oldPtr?.item?.id !== newPtr.item.id) {
    if (highlightTimeout) clearTimeout(highlightTimeout)
    highlightedId.value = newPtr.item.id
    highlightTimeout = setTimeout(() => {
      highlightedId.value = null
    }, 1000)
  }
})

onMounted(() => { tickerId = setInterval(() => tick.value++, 250) })
onBeforeUnmount(() => {
  if (tickerId) clearInterval(tickerId)
  if (highlightTimeout) clearTimeout(highlightTimeout)
})

function fmt(ms) { return formatMs(ms) }
function itemElapsed(item) { return itemElapsedMs(item.id) + (tick.value&&0) }
function sectionTotal(sectionKey) { return sectionTotalMs(sectionKey) }

async function beginEdit(item) {
  editId.value = item.id
  editText.value = item.title
  await nextTick()
  const inputs = document.querySelectorAll('.edit')
  const lastInput = inputs[inputs.length - 1]
  if (lastInput) lastInput.focus()
}
function commitEdit(item) { setTitle(item.id, editText.value); editId.value = null }
function cancelEdit() { editId.value = null }

async function manualTime(item) {
  const current = formatMs(itemElapsedMs(item.id))
  const { ok, text } = await new Promise(resolve => {
    $q.dialog({
      title: 'Definir tempo',
      message: 'Digite o tempo no formato mm:ss',
      prompt: {
        model: current,
        type: 'text',
        placeholder: 'Ex: 05:30'
      },
      cancel: true,
      persistent: true
    }).onOk(text => resolve({ ok: true, text })).onCancel(() => resolve({ ok: false, text: null })).onDismiss(() => resolve({ ok: false, text: null }))
  })
  if (!ok || !text) return
  const ms = parseMmSs(text)
  setManualTime(item.id, ms)
}

async function sectionActions(sectionKey) {
  const cur = currentPointer()
  const choice = await new Promise(resolve => {
    $q.dialog({
      title: 'Ações da seção',
      message: 'Escolha uma ação:',
      options: {
        type: 'radio',
        model: 'add',
        items: [
          { label: 'Adicionar parte', value: 'add' },
          { label: 'Adicionar subparte (na parte atual)', value: 'addSub', disable: !cur || (cur.type) },
          { label: 'Remover parte atual', value: 'remove', disable: !cur || cur.type }
        ]
      },
      cancel: true,
      persistent: true
    }).onOk(value => resolve(value)).onCancel(() => resolve(null)).onDismiss(() => resolve(null))
  })
  if (!choice) return
  if (choice === 'add') {
    addPart(sectionKey)
    return
  }
  if (choice === 'addSub') {
    if (!cur || !cur.section || cur.type) return
    const parentId = cur.section === sectionKey && cur.index >= 0 ? (state[sectionKey][cur.index]?.id) : null
    if (parentId) addSubPart(sectionKey, parentId)
    return
  }
  if (choice === 'remove') {
    if (!cur || cur.type || !cur.section) return
    const idToRemove = cur.subIndex >= 0 ? (state[cur.section][cur.index].sub_parts[cur.subIndex].id) : state[cur.section][cur.index].id
    removeItem(cur.section, idToRemove)
  }
}

defineExpose({ reportRoot })

const hasData = computed(() =>
  (state.treasures?.length || 0) + (state.ministries?.length || 0) + (state.christian_life?.length || 0) > 0
)
</script>

<style scoped>
.report { padding: 16px; color: #222; padding-bottom: 120px; }
.center { text-align: center; }
.report-title { font-size: 20px; margin: 6px 0 10px; font-weight: 700; }
.meta { margin: 12px 0; font-size: 16px; }
.sec { margin-top: 18px; }
.sec-header { display:flex; align-items:center; gap:12px; font-weight: 800; font-size: 20px; }
.sec-header.teal { color:#1e6e6e }
.sec-header.amber { color:#a86b00 }
.sec-header.red { color:#8a1b1b }
.line { display:block; padding:6px 0; }
.line-main { display:flex; align-items:center; gap:8px; }
.sline { display:flex; gap:8px; padding:2px 0; margin-left: 20px; white-space: nowrap; }
.idx { width: 22px; }
.t { flex: 1; overflow: hidden; text-overflow: ellipsis; cursor: pointer; user-select: none; transition: color 0.2s; }
.t:hover { text-decoration: underline; }
.t.highlight-green { color: #4caf50 !important; font-weight: bold; }
.sline .s-edit, .sline span:first-child { flex: 1; overflow: hidden; text-overflow: ellipsis; }
.v { font-family: monospace; cursor: pointer; user-select: none; }
.v:hover { background-color: rgba(0,0,0,0.05); border-radius: 4px; padding: 2px 4px; }
.edit { padding: 4px 8px; border: 2px solid #1976d2; border-radius: 4px; font-size: inherit; min-width: 200px; }
.icon { font-size: 26px }
.sec-icon { width: 28px; height: 28px; object-fit: contain; }
.bottom { margin-top: 20px; }
.empty { margin: 40px 0; text-align: center; color: #666; }
</style>

