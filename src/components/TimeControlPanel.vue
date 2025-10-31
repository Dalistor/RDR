<template>
  <div class="panel">
    <div class="toolbar">
      <button class="btn" @click="onAdd('treasures')">+ Tesouros</button>
      <button class="btn" @click="onAdd('ministries')">+ Ministério</button>
      <button class="btn" @click="onAdd('christian_life')">+ Vida Cristã</button>
    </div>

    <section v-for="section in sections" :key="section.key" class="section">
      <h3 :class="['title', section.key]">{{ section.label }}</h3>

      <div v-for="item in state[section.key]" :key="item.id" class="item">
        <input class="title-input" v-model="item.title" />
        <span class="time">{{ fmt(itemElapsed(item)) }}</span>
        <button class="btn" @click="start(item)">Iniciar</button>
        <button class="btn" @click="stop(item)">Parar</button>
        <button class="btn" @click="reset(item)">Zerar</button>
        <button class="btn danger" @click="remove(section.key, item.id)">Remover</button>
        <button class="btn" @click="addSub(section.key, item.id)">+ Subparte</button>

        <div v-if="item.sub_parts?.length" class="sublist">
          <div v-for="sub in item.sub_parts" :key="sub.id" class="subitem">
            <input class="title-input" v-model="sub.title" />
            <span class="time">{{ fmt(itemElapsed(sub)) }}</span>
            <button class="btn" @click="start(sub)">Iniciar</button>
            <button class="btn" @click="stop(sub)">Parar</button>
            <button class="btn" @click="reset(sub)">Zerar</button>
            <button class="btn danger" @click="remove(section.key, sub.id)">Remover</button>
          </div>
        </div>
      </div>
    </section>
  </div>

</template>

<script setup>
import { onMounted } from 'vue'
import { state, startTimer, stopTimer, resetTimer, addPart, addSubPart, removeItem, itemElapsedMs, saveToLocalStorage } from 'src/stores/timerStore'
import { formatMs } from 'src/utils/time'

const sections = [
  { key: 'treasures', label: 'TESOUROS DA PALAVRA DE DEUS' },
  { key: 'ministries', label: 'FAÇA SEU MELHOR NO MINISTÉRIO' },
  { key: 'christian_life', label: 'NOSSA VIDA CRISTÃ' }
]

function fmt(ms) { return formatMs(ms) }
function itemElapsed(item) { return itemElapsedMs(item.id) }

function start(item) { startTimer(item.id); saveToLocalStorage() }
function stop(item) { stopTimer(item.id); saveToLocalStorage() }
function reset(item) { resetTimer(item.id); saveToLocalStorage() }
function onAdd(sectionKey) { addPart(sectionKey); saveToLocalStorage() }
function addSub(sectionKey, parentId) { addSubPart(sectionKey, parentId); saveToLocalStorage() }
function remove(sectionKey, id) { removeItem(sectionKey, id); saveToLocalStorage() }

onMounted(() => {
  // nada extra
})
</script>

<style scoped>
.panel { padding: 16px; }
.toolbar { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
.btn { background: #eee; border: 1px solid #ccc; padding: 6px 10px; border-radius: 6px; cursor: pointer; }
.btn.danger { background: #ffe5e5; border-color: #ff9b9b; }
.section { margin-bottom: 20px; }
.title { font-weight: 700; margin: 12px 0; }
.title.treasures { color: #1e6e6e; }
.title.ministries { color: #a86b00; }
.title.christian_life { color: #8a1b1b; }
.item, .subitem { display: flex; align-items: center; gap: 8px; padding: 6px 0; }
.sublist { margin-left: 24px; }
.title-input { flex: 1; min-width: 200px; padding: 6px 8px; border: 1px solid #ccc; border-radius: 6px; }
.time { font-family: monospace; width: 60px; text-align: right; }
</style>

