export function formatMs(ms) {
  if (!ms || ms < 0 || Number.isNaN(ms)) ms = 0;
  const minutes = Math.floor(ms / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export function nowMs() {
  return Date.now();
}

export function formatHM(date = new Date()) {
  const h = String(date.getHours()).padStart(2, '0')
  const m = String(date.getMinutes()).padStart(2, '0')
  return `${h}:${m}`
}

export function uuid() {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

export function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

// pequeno util para forçar reatividade periódica
export function createTicker(intervalMs = 250) {
  let id;
  const subscribers = new Set();
  function start() {
    if (id) return;
    id = setInterval(() => subscribers.forEach(fn => fn()), intervalMs);
  }
  function stop() {
    if (!id) return;
    clearInterval(id); id = undefined;
  }
  function onTick(cb) { subscribers.add(cb); return () => subscribers.delete(cb) }
  start();
  return { start, stop, onTick };
}

export function parseMmSs(text) {
  if (!text) return 0;
  const parts = String(text).trim().split(':');
  let m = 0, s = 0;
  if (parts.length === 2) { m = parseInt(parts[0]||'0',10); s = parseInt(parts[1]||'0',10); }
  else if (parts.length === 1) { s = parseInt(parts[0]||'0',10); }
  const ms = Math.max(0, (isNaN(m)?0:m)*60000 + (isNaN(s)?0:s)*1000);
  return ms;
}

