# Checklist de Integração do JAR

## 1. Verificar se o JAR existe
- [ ] Arquivo existe em: `src-capacitor/android/app/libs/mobileapi.jar`
- [ ] Tamanho do arquivo > 0 bytes

## 2. Inspecionar o JAR
Execute para ver as classes dentro do JAR:
```powershell
cd src-capacitor/android/app/libs
jar -tf mobileapi.jar | findstr /i "\.class"
```

Procure por:
- `mobileapi/Mobileapi.class` (classe principal)
- Métodos que devem existir: `startServer`, `stopServer` ou `StartServer`, `StopServer`

## 3. Compilar e testar no Android
```powershell
# Do diretório raiz do projeto
quasar build -m capacitor -T android
npx cap sync android
npx cap open android
```

## 4. Verificar logs no Android Studio
Após rodar o app, verifique no Logcat:
- Filtrar por tag: `RdrMobileApiPlugin`
- Procurar por:
  - ✅ "Classe mobileapi.Mobileapi carregada com sucesso!"
  - ❌ "Falha ao carregar classe mobileapi.Mobileapi"
  - ✅ "Servidor iniciado com sucesso!"
  - ❌ Erros de NoSuchMethodException (indica nome de método errado)

## 5. Possíveis problemas e soluções

### Problema: Classe não encontrada
**Causa**: O pacote/classe no JAR tem nome diferente
**Solução**: Inspecione o JAR (passo 2) e ajuste linha 26 do RdrMobileApiPlugin.java

### Problema: NoSuchMethodException
**Causa**: Nome do método está errado (StartServer vs startServer)
**Solução**: 
- Go exporta funções iniciadas com maiúscula
- Gomobile pode converter para Java seguindo convenções
- Verifique se é `StartServer` ou `startServer` no JAR
- Ajuste linhas 46 e 64 do RdrMobileApiPlugin.java

### Problema: App carrega mas usa SAMPLE
**Causa**: Servidor não está respondendo em localhost:12765
**Solução**:
- Verifique permissões de internet no AndroidManifest.xml
- Adicione se necessário:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<application android:usesCleartextTraffic="true" ...>
```

## 6. Teste manual no browser console
Após abrir o app compilado, abra o Chrome DevTools (chrome://inspect) e teste:
```javascript
// Verificar se o plugin está disponível
window.Capacitor.Plugins.RdrMobileApiPlugin

// Testar startServer
await window.mobileApi.startServer('12765', 'RELEASE')

// Testar getMeetingJson
await window.mobileApi.getMeetingJson('12765')
```

## 7. Verificar se o servidor Go responde
Após iniciar o servidor via plugin, teste com adb:
```powershell
adb shell "curl http://127.0.0.1:12765/meeting"
```





