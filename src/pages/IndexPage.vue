<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-md">
      <div class="row items-center q-gutter-sm">
        <q-space/>
        <q-btn color="secondary" label="Exportar PDF" @click="exportPdf"/>
        <q-btn color="negative" label="Novo relatório" @click="newReport"/>
      </div>

      <div v-if="!loaded" class="row justify-center q-mt-xl">
        <q-spinner size="40px" color="primary"/>
      </div>

      <ReportView ref="reportRef" :loading="!loaded"/>

      <ControlPanelDialog v-model="showPanel" />
      <NowControlBar @open-panel="showPanel=true" />
    </div>
  </q-page>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import ReportView from 'src/components/ReportView.vue'
import ControlPanelDialog from 'src/components/ControlPanelDialog.vue'
import NowControlBar from 'src/components/NowControlBar.vue'
import { useQuasar } from 'quasar'
import { loadFromLocalStorage, initializeFromApi, saveToLocalStorage, state } from 'src/stores/timerStore'

const $q = useQuasar()

const reportRef = ref(null)
const loaded = ref(false)
const showPanel = ref(false)

onMounted(async () => {
  const ok = loadFromLocalStorage()
  // inicia servidor AAR e busca JSON via HTTP local
  await window.mobileApi.startServer('12765', 'RELEASE')
  if (!ok) {
    const data = await window.mobileApi.getMeetingJson('12765')
    initializeFromApi(data)
    saveToLocalStorage()
  }
  loaded.value = true
})

async function exportPdf() {
  const el = reportRef.value?.reportRoot
  if (!el) return
  if (!window.html2pdf) {
    await loadHtml2Pdf()
  }
  window.html2pdf().from(el).set({ margin: 10, filename: 'relatorio.pdf' }).save()
}

async function loadHtml2Pdf() {
  await new Promise((resolve, reject) => {
    const s = document.createElement('script')
    s.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js'
    s.onload = resolve
    s.onerror = reject
    document.head.appendChild(s)
  })
}

async function newReport() {
  try {
    // confirmação de nova reunião
    const confirmed = await new Promise(resolve => {
      $q.dialog({
        title: 'Nova reunião',
        message: 'Tem certeza que deseja iniciar uma nova reunião?',
        cancel: true,
        persistent: true
      }).onOk(() => resolve(true)).onCancel(() => resolve(false)).onDismiss(() => resolve(false))
    })
    if (!confirmed) return

    localStorage.removeItem('rdr:meeting-state')

    $q.loading.show({
      message: 'Carregando dados do servidor...'
    })

    // Garante que o servidor está rodando (não precisa parar, apenas reiniciar se necessário)
    try {
      await window.mobileApi?.startServer?.('12765', 'RELEASE')
    } catch (e) {
      console.warn('startServer falhou', e)
    }

    // Aguarda um pouco para garantir que o servidor está pronto
    await new Promise(r => setTimeout(r, 500))

    // Busca novos dados diretamente do servidor
    const data = await window.mobileApi.getMeetingJson('12765')

    $q.loading.hide()

    initializeFromApi(data)
    saveToLocalStorage()
    showPanel.value = false
  } catch (error) {
    $q.loading.hide()
    $q.notify({
      type: 'negative',
      message: 'Erro ao carregar nova reunião: ' + error.message,
      position: 'top'
    })
  }
}

onBeforeUnmount(() => {
  window.mobileApi.stopServer(500)
})
</script>
