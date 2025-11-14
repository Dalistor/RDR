import { reactive, computed } from 'vue'
import { formatMs, nowMs, uuid, deepClone, formatHM } from 'src/utils/time'

const STORAGE_KEY = 'rdr:meeting-state'

function enhanceItem(raw) {
  const item = {
    id: uuid(),
    title: raw.title || '',
    running: false,
    startAt: null,
    endAt: null,
    elapsedMs: 0,
    sub_parts: Array.isArray(raw.sub_parts) ? raw.sub_parts.map(enhanceItem) : undefined
  }
  return item
}

function computeElapsed(item) {
  if (item.running && item.startAt) {
    return item.elapsedMs + (nowMs() - item.startAt)
  }
  return item.elapsedMs
}

export const state = reactive({
  meta: {
    date: '',
    initial_time: '',
    final_time: '',
    final_comments: ''
  },
  opening_comments: { id: 'opening_comments', title: 'Comentários iniciais', running: false, startAt: null, endAt: null, elapsedMs: 0 },
  treasures: [],
  ministries: [],
  christian_life: [],
  final_comments: { id: 'final_comments', title: 'Comentários finais', running: false, startAt: null, endAt: null, elapsedMs: 0 },
  loaded: false,
  pointer: { type: 'opening_comments' }
})

export function loadFromLocalStorage() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return false
    const data = JSON.parse(raw)
    Object.assign(state, data)
    state.loaded = true
    return true
  } catch (e) {
    console.error('loadFromLocalStorage', e)
    return false
  }
}

export function saveToLocalStorage() {
  const snapshot = deepClone(state)
  localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot))
}

export function initializeFromApi(json) {
  // Limpa completamente o estado anterior
  state.meta = {
    date: json.meta?.date || '',
    initial_time: '',
    final_time: '',
    final_comments: ''
  }
  state.treasures = (json.treasures || []).map(enhanceItem)
  state.ministries = (json.ministries || []).map(enhanceItem)
  state.christian_life = (json.christian_life || []).map(enhanceItem)
  state.opening_comments = { id: 'opening_comments', title: 'Comentários iniciais', running: false, startAt: null, endAt: null, elapsedMs: 0 }
  state.final_comments = { id: 'final_comments', title: 'Comentários finais', running: false, startAt: null, endAt: null, elapsedMs: 0 }
  state.loaded = true
  state.pointer = { type: 'opening_comments' }
}

function findItemById(list, id) {
  for (const part of list) {
    if (part.id === id) return part
    if (part.sub_parts) {
      const q = findItemById(part.sub_parts, id)
      if (q) return q
    }
  }
  return null
}

export function startTimer(id) {
  if (id === 'opening_comments' || id === 'final_comments') {
    const item = state[id]
    if (item && !item.running) {
      item.running = true
      item.startAt = nowMs()
      return true
    }
    return false
  }
  const lists = [state.treasures, state.ministries, state.christian_life]
  for (const lst of lists) {
    const item = findItemById(lst, id)
    if (item) {
      if (!item.running) {
        item.running = true
        item.startAt = nowMs()
      }
      return true
    }
  }
  return false
}

export function stopTimer(id) {
  if (id === 'opening_comments' || id === 'final_comments') {
    const item = state[id]
    if (item && item.running) {
      item.elapsedMs += nowMs() - (item.startAt || nowMs())
      item.running = false
      item.startAt = null
      return true
    }
    return false
  }
  const lists = [state.treasures, state.ministries, state.christian_life]
  for (const lst of lists) {
    const item = findItemById(lst, id)
    if (item && item.running) {
      item.elapsedMs += nowMs() - (item.startAt || nowMs())
      item.running = false
      item.startAt = null
      return true
    }
  }
  return false
}

export function resetTimer(id) {
  if (id === 'opening_comments' || id === 'final_comments') {
    const item = state[id]
    if (item) {
      item.running = false
      item.startAt = null
      item.elapsedMs = 0
      return true
    }
    return false
  }
  const lists = [state.treasures, state.ministries, state.christian_life]
  for (const lst of lists) {
    const item = findItemById(lst, id)
    if (item) {
      item.running = false
      item.startAt = null
      item.elapsedMs = 0
      return true
    }
  }
  return false
}

export function addPart(sectionKey) {
  const target = state[sectionKey]
  if (!Array.isArray(target)) return
  target.push(enhanceItem({ title: 'Novo item' }))
}

export function removeItem(sectionKey, id) {
  const target = state[sectionKey]
  if (!Array.isArray(target)) return
  const idx = target.findIndex(p => p.id === id)
  if (idx !== -1) {
    target.splice(idx, 1)
    return
  }
  for (const p of target) {
    if (Array.isArray(p.sub_parts)) {
      const si = p.sub_parts.findIndex(sp => sp.id === id)
      if (si !== -1) {
        p.sub_parts.splice(si, 1)
        return
      }
    }
  }
}

export function addSubPart(sectionKey, parentId) {
  const target = state[sectionKey]
  for (const p of target) {
    if (p.id === parentId) {
      if (!Array.isArray(p.sub_parts)) p.sub_parts = []
      p.sub_parts.push(enhanceItem({ title: 'Subparte' }))
      return true
    }
    if (p.sub_parts) {
      const pp = findItemById(p.sub_parts, parentId)
      if (pp) {
        if (!Array.isArray(pp.sub_parts)) pp.sub_parts = []
        pp.sub_parts.push(enhanceItem({ title: 'Subparte' }))
        return true
      }
    }
  }
  return false
}

export function setTitle(id, newTitle) {
  if (id === 'opening_comments' || id === 'final_comments') {
    state[id].title = newTitle
    return true
  }
  const lists = [state.treasures, state.ministries, state.christian_life]
  for (const lst of lists) {
    const item = findItemById(lst, id)
    if (item) {
      item.title = newTitle
      return true
    }
  }
  return false
}

export function setManualTime(id, ms) {
  if (id === 'opening_comments' || id === 'final_comments') {
    const item = state[id]
    if (item) {
      item.elapsedMs = Math.max(0, Number(ms) || 0)
      item.startAt = null
      item.running = false
      return true
    }
    return false
  }
  const lists = [state.treasures, state.ministries, state.christian_life]
  for (const lst of lists) {
    const item = findItemById(lst, id)
    if (item) {
      item.elapsedMs = Math.max(0, Number(ms) || 0)
      item.startAt = null
      item.running = false
      return true
    }
  }
  return false
}

export function flatten() {
  const arr = []
  // Comentários iniciais primeiro
  arr.push({ type: 'opening_comments', item: state.opening_comments })
  // Partes normais
  const pushSection = (sectionKey) => {
    const list = state[sectionKey] || []
    list.forEach((p, idx) => {
      arr.push({ section: sectionKey, index: idx, subIndex: -1, item: p })
      if (Array.isArray(p.sub_parts)) {
        p.sub_parts.forEach((sp, sidx) => {
          arr.push({ section: sectionKey, index: idx, subIndex: sidx, item: sp })
        })
      }
    })
  }
  pushSection('treasures')
  pushSection('ministries')
  pushSection('christian_life')
  // Comentários finais por último
  arr.push({ type: 'final_comments', item: state.final_comments })
  return arr
}

export function currentPointer() {
  if (state.pointer.type === 'opening_comments') {
    return { type: 'opening_comments', item: state.opening_comments }
  }
  if (state.pointer.type === 'final_comments') {
    return { type: 'final_comments', item: state.final_comments }
  }
  const { section, index, subIndex } = state.pointer
  const list = state[section] || []
  const parent = list[index]
  if (!parent) return null
  if (subIndex >= 0) return parent.sub_parts?.[subIndex] ? { item: parent.sub_parts[subIndex], section, index, subIndex } : null
  return { item: parent, section, index, subIndex }
}

export function moveNext() {
  const flat = flatten()
  const cur = currentPointer()
  if (!flat.length) return
  let pos = 0
  if (cur) {
    pos = flat.findIndex(x => x.item.id === cur.item.id)
    if (pos < 0) pos = -1
  } else {
    pos = -1
  }
  const nxt = flat[(pos + 1) % flat.length]
  if (nxt.type === 'opening_comments' || nxt.type === 'final_comments') {
    state.pointer = { type: nxt.type }
  } else {
    state.pointer = { section: nxt.section, index: nxt.index, subIndex: nxt.subIndex }
  }
}

export function movePrev() {
  const flat = flatten()
  const cur = currentPointer()
  if (!flat.length) return
  let pos = 0
  if (cur) {
    pos = flat.findIndex(x => x.item.id === cur.item.id)
    if (pos < 0) pos = 0
  } else {
    pos = 0
  }
  const prevPos = pos - 1 < 0 ? flat.length - 1 : pos - 1
  const prev = flat[prevPos]
  if (prev.type === 'opening_comments' || prev.type === 'final_comments') {
    state.pointer = { type: prev.type }
  } else {
    state.pointer = { section: prev.section, index: prev.index, subIndex: prev.subIndex }
  }
}

export function toggleStartStopCurrent() {
  const cur = currentPointer()
  if (!cur) return
  const id = cur.item.id
  const running = cur.item.running
  if (running) {
    stopTimer(id)
    moveNext()
  } else {
    startTimer(id)
  }
}

export function itemElapsedMs(id) {
  if (id === 'opening_comments' || id === 'final_comments') {
    return computeElapsed(state[id])
  }
  const lists = [state.treasures, state.ministries, state.christian_life]
  for (const lst of lists) {
    const item = findItemById(lst, id)
    if (item) return computeElapsed(item)
  }
  return 0
}

export function sectionTotalMs(sectionKey) {
  const target = state[sectionKey] || []
  let total = 0
  const stack = [...target]
  while (stack.length) {
    const it = stack.pop()
    total += computeElapsed(it)
    if (Array.isArray(it.sub_parts)) stack.push(...it.sub_parts)
  }
  return total
}

export const getters = {
  format(ms) { return formatMs(ms) }
}

// Auto-save tick
setInterval(() => {
  saveToLocalStorage()
}, 1000)

// Marcar horários de reunião
export function markMeetingStartNow() {
  state.meta.initial_time = formatHM(new Date())
}

export function markMeetingEndNow() {
  state.meta.final_time = formatHM(new Date())
}


