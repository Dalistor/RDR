// Bridge JS para chamar o plugin Capacitor que encapsula o AAR
import { boot } from 'quasar/wrappers'

const SAMPLE = {
  meta: { date: '', initial_time: '', final_time: '', final_comments: '' },
  treasures: [
    { title: '1. Tenha uma vida feliz e saudável', sub_parts: [{ title: 'Presidente' }] },
    { title: '2. Joias espirituais', sub_parts: [{ title: 'Presidente' }] },
    { title: '3. Leitura da Bíblia', sub_parts: [{ title: 'Conselho' }, { title: 'Transição' }] }
  ],
  ministries: [
    { title: '4. Cultivando o interesse', sub_parts: [{ title: 'Conselho' }, { title: 'Transição' }] },
    { title: '5. Cultivando o interesse', sub_parts: [{ title: 'Conselho' }, { title: 'Transição' }] },
    { title: '6. Discurso', sub_parts: [{ title: 'Conselho' }, { title: 'Transição' }] }
  ],
  christian_life: [
    { title: '7. Necessidades locais', sub_parts: [{ title: 'Presidente' }] },
    { title: '8. Estudo bíblico de congregação' }
  ]
}

export default boot(() => {
  const w = window
  const Plugins = (w.Capacitor && w.Capacitor.Plugins) || (w.Capacitor && w.Capacitor.Plugins) || {}
  const Native = Plugins?.RdrMobileApiPlugin

  w.mobileApi = {
    async startServer(port = '12765', mode = 'RELEASE') {
      try {
        if (Native?.startServer) {
          await Native.startServer({ port, mode })
          return { port }
        }
      } catch (e) {
        console.warn('startServer falhou', e)
      }
      return { port }
    },
    async stopServer(timeoutMs = 500) {
      try {
        if (Native?.stopServer) await Native.stopServer({ timeoutMs })
      } catch (e) {
        console.warn('stopServer falhou', e)
      }
    },
    async getMeetingJson(port = '12765') {
      try {
        const res = await fetch(`http://127.0.0.1:${port}/meeting`)
        if (!res.ok) throw new Error(res.statusText)
        return await res.json()
      } catch (e) {
        console.warn('GET /meeting falhou, usando SAMPLE', e)
        return SAMPLE
      }
    }
  }
})



