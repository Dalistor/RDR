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
  console.log('[aar-bridge] Inicializando...')
  console.log('[aar-bridge] Capacitor disponível?', !!w.Capacitor)
  const Plugins = (w.Capacitor && w.Capacitor.Plugins) || {}
  console.log('[aar-bridge] Plugins disponíveis:', Object.keys(Plugins))
  const Native = Plugins?.RdrMobileApiPlugin
  console.log('[aar-bridge] RdrMobileApiPlugin disponível?', !!Native)

  w.mobileApi = {
    async startServer(port = '12765', mode = 'RELEASE') {
      console.log('[mobileApi] startServer chamado', { port, mode, nativeDisponivel: !!Native })
      try {
        if (Native?.startServer) {
          console.log('[mobileApi] Chamando Native.startServer...')
          const result = await Native.startServer({ port, mode })
          console.log('[mobileApi] Servidor iniciado na porta', port, result)
          return { port }
        } else {
          console.warn('[mobileApi] Native.startServer não disponível')
        }
      } catch (e) {
        console.error('[mobileApi] startServer falhou', e)
      }
      return { port }
    },
    async stopServer(timeoutMs = 500) {
      try {
        if (Native?.stopServer) {
          await Native.stopServer({ timeoutMs })
          console.log('Servidor parado')
        }
      } catch (e) {
        console.warn('stopServer falhou', e)
      }
    },
    async getMeetingJson(port = '12765') {
      try {
        // Aguarda um pouco para garantir que o servidor esteja pronto
        await new Promise(r => setTimeout(r, 300))
        const res = await fetch(`http://127.0.0.1:${port}/meeting`, {
          method: 'GET',
          headers: { 'Accept': 'application/json' }
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`)
        const data = await res.json()
        console.log('Dados recebidos do servidor', data)
        return data
      } catch (e) {
        console.warn('GET /meeting falhou, usando SAMPLE', e)
        return SAMPLE
      }
    }
  }
})



