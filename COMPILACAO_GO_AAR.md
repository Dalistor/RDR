# Compilação do Servidor Go para AAR e Integração no Mobile

Este documento descreve o processo completo de compilação do servidor Go em uma biblioteca Android (AAR) e sua integração no aplicativo mobile usando Capacitor.

## Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Estrutura do Projeto Go](#estrutura-do-projeto-go)
3. [Compilação com gomobile](#compilação-com-gomobile)
4. [Integração no Android](#integração-no-android)
5. [Plugin Capacitor](#plugin-capacitor)
6. [Bridge JavaScript](#bridge-javascript)
7. [Troubleshooting](#troubleshooting)

---

## Pré-requisitos

### Ferramentas Necessárias

1. **Go** (versão 1.24.3 ou superior)
2. **gomobile** - Ferramenta para compilar Go para Android/iOS
3. **Android SDK** - Para desenvolvimento Android
4. **Gradle** - Sistema de build do Android
5. **Capacitor** - Framework para apps híbridos

### Instalação do gomobile

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

---

## Estrutura do Projeto Go

### Módulo Go

O projeto Go está localizado em `api/` e possui a seguinte estrutura:

```
api/
├── go.mod                    # Módulo: rdr/scraper
├── pkg/
│   └── mobileapi/
│       └── mobileapi.go      # Funções exportadas para mobile
├── internal/
│   ├── web/
│   │   ├── handlers/
│   │   ├── services/
│   │   ├── types/
│   │   └── ulrs/
│   └── services/
│       └── scrap/
└── cmd/
    └── api/
        └── main.go
```

### Arquivo Principal: `api/pkg/mobileapi/mobileapi.go`

Este arquivo contém as funções que serão exportadas para o Android:

```go
package mobileapi

import (
    "context"
    "net"
    "net/http"
    "time"
    
    "rdr/scraper/cmd/settings"
    "rdr/scraper/internal/web/ulrs"
    
    "github.com/gin-gonic/gin"
)

var httpServer *http.Server

// StartServer inicia o servidor REST em 127.0.0.1:port no modo (RELEASE/DEBUG)
func StartServer(port string, mode string) error {
    // Configuração do servidor Gin
    switch mode {
    case "RELEASE":
        gin.SetMode(gin.ReleaseMode)
    case "DEBUG":
        gin.SetMode(gin.DebugMode)
    default:
        gin.SetMode(gin.ReleaseMode)
    }

    router := gin.New()
    router.Use(gin.Recovery(), settings.Cors())
    ulrs.SetUrls(router)

    httpServer = &http.Server{
        Addr:    "127.0.0.1:" + port,
        Handler: router,
    }
    go func() { _ = httpServer.ListenAndServe() }()

    // Aguarda até o socket estar up (ou timeout)
    deadline := time.Now().Add(3 * time.Second)
    for time.Now().Before(deadline) {
        conn, err := net.DialTimeout("tcp", "127.0.0.1:"+port, 200*time.Millisecond)
        if err == nil {
            _ = conn.Close()
            return nil
        }
        time.Sleep(100 * time.Millisecond)
    }
    return nil
}

// StopServer encerra o servidor HTTP de forma graciosa
func StopServer(timeoutMs int) error {
    if httpServer == nil {
        return nil
    }
    ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
    defer cancel()
    return httpServer.Shutdown(ctx)
}
```

**Pontos Importantes:**
- As funções devem ser exportadas (começar com letra maiúscula)
- Os tipos de parâmetros devem ser compatíveis com Java (string, int, etc.)
- O pacote deve ser `mobileapi` para gerar a classe `mobileapi.mobileapi.Mobileapi`

---

## Compilação com gomobile

### Passo 1: Navegar para o diretório da API

```bash
cd api
```

### Passo 2: Compilar para AAR

```bash
gomobile bind -target=android -o dist/mobileapi.aar rdr/scraper/pkg/mobileapi
```

**Parâmetros:**
- `-target=android`: Compila para Android
- `-o dist/mobileapi.aar`: Arquivo de saída (AAR)
- `rdr/scraper/pkg/mobileapi`: Caminho do pacote Go a ser compilado

### Passo 3: Verificar o AAR gerado

O comando acima gera:
- `dist/mobileapi.aar` - Arquivo AAR contendo:
  - `classes.jar` - Classes Java compiladas
  - `AndroidManifest.xml` - Manifest do AAR
  - `jni/` - Bibliotecas nativas (`.so`) para diferentes arquiteturas:
    - `armeabi-v7a/libgojni.so`
    - `arm64-v8a/libgojni.so`
    - `x86/libgojni.so`
    - `x86_64/libgojni.so`

### Estrutura Interna do AAR

Para verificar o conteúdo do AAR:

```bash
cd api/dist
jar -tf mobileapi.aar
```

Saída esperada:
```
AndroidManifest.xml
proguard.txt
classes.jar
jni/armeabi-v7a/libgojni.so
jni/arm64-v8a/libgojni.so
jni/x86/libgojni.so
jni/x86_64/libgojni.so
R.txt
res/
```

### Verificar Classes Compiladas

Para ver as classes Java geradas:

```bash
jar -xf mobileapi.aar classes.jar
jar -tf classes.jar
```

A classe principal será: `mobileapi/mobileapi/Mobileapi.class`

---

## Integração no Android

### Passo 1: Copiar o AAR para o projeto Android

```bash
# Do diretório raiz do projeto
Copy-Item -Path "api\dist\mobileapi.aar" -Destination "src-capacitor\android\app\libs\mobileapi.aar" -Force
```

### Passo 2: Configurar o build.gradle

Editar `src-capacitor/android/app/build.gradle`:

```gradle
repositories {
    flatDir {
        dirs 'libs'
    }
}

dependencies {
    // Incluir JARs
    implementation fileTree(include: ['*.jar'], dir: 'libs')
    
    // Incluir AAR específico
    implementation(name: 'mobileapi', ext: 'aar')
    
    // Outras dependências...
}
```

**Importante:** 
- O repositório `flatDir` permite incluir arquivos locais
- O AAR deve estar na pasta `libs/`
- Use `implementation(name: 'mobileapi', ext: 'aar')` para incluir o AAR

### Passo 3: Configurar AndroidManifest.xml

Adicionar permissão para tráfego HTTP (necessário para servidor local):

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
</application>
```

---

## Plugin Capacitor

### Estrutura do Plugin

O plugin Capacitor está em `src-capacitor/android/app/src/main/java/org/rdr/RdrMobileApiPlugin.java`

### Implementação do Plugin

```java
package org.rdr;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.JSObject;

@CapacitorPlugin(name = "RdrMobileApiPlugin")
public class RdrMobileApiPlugin extends Plugin {

    private static final String DEFAULT_PORT = "12765";
    private static final String DEFAULT_MODE = "RELEASE";
    
    private Class<?> mobileApiClass;

    @Override
    public void load() {
        super.load();
        try {
            // Carregar a classe do AAR
            mobileApiClass = Class.forName("mobileapi.mobileapi.Mobileapi");
            android.util.Log.i("RdrMobileApiPlugin", "Classe carregada com sucesso!");
        } catch (Throwable e) {
            android.util.Log.e("RdrMobileApiPlugin", "Falha ao carregar classe: " + e.getMessage());
            mobileApiClass = null;
        }
    }

    @PluginMethod
    public void startServer(PluginCall call) {
        String port = call.getString("port", DEFAULT_PORT);
        String mode = call.getString("mode", DEFAULT_MODE);
        
        try {
            if (mobileApiClass == null) {
                throw new IllegalStateException("Classe mobileapi.mobileapi.Mobileapi não encontrada");
            }
            
            // Invocar método StartServer usando reflection
            try {
                mobileApiClass.getMethod("StartServer", String.class, String.class)
                    .invoke(null, port, mode);
            } catch (NoSuchMethodException e) {
                // Fallback para minúsculo
                mobileApiClass.getMethod("startServer", String.class, String.class)
                    .invoke(null, port, mode);
            }
            
            JSObject ret = new JSObject();
            ret.put("port", port);
            call.resolve(ret);
        } catch (Throwable t) {
            call.reject("Falha ao iniciar servidor: " + t.getMessage());
        }
    }

    @PluginMethod
    public void stopServer(PluginCall call) {
        int timeoutMs = call.getInt("timeoutMs", 500);
        try {
            if (mobileApiClass == null) {
                throw new IllegalStateException("Classe não encontrada");
            }
            
            try {
                mobileApiClass.getMethod("StopServer", int.class)
                    .invoke(null, timeoutMs);
            } catch (NoSuchMethodException e) {
                mobileApiClass.getMethod("stopServer", int.class)
                    .invoke(null, timeoutMs);
            }
            
            call.resolve();
        } catch (Throwable t) {
            call.reject("Falha ao parar servidor: " + t.getMessage());
        }
    }
}
```

**Pontos Importantes:**
- A classe gerada pelo gomobile é `mobileapi.mobileapi.Mobileapi`
- Os métodos Go são expostos como métodos estáticos em Java
- Use reflection para invocar os métodos
- O gomobile gera métodos com primeira letra maiúscula (padrão Go)

### Registro do Plugin

Registrar o plugin em `MainActivity.java`:

```java
package org.rdr;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        registerPlugin(RdrMobileApiPlugin.class);
    }
}
```

---

## Bridge JavaScript

### Arquivo: `src/boot/aar-bridge.js`

Este arquivo cria uma interface JavaScript para o plugin Capacitor:

```javascript
import { boot } from 'quasar/wrappers'

export default boot(() => {
  const w = window
  const Plugins = (w.Capacitor && w.Capacitor.Plugins) || {}
  const Native = Plugins?.RdrMobileApiPlugin

  w.mobileApi = {
    async startServer(port = '12765', mode = 'RELEASE') {
      try {
        if (Native?.startServer) {
          const result = await Native.startServer({ port, mode })
          return { port }
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
        }
      } catch (e) {
        console.warn('stopServer falhou', e)
      }
    },
    
    async getMeetingJson(port = '12765') {
      try {
        // Aguarda servidor estar pronto
        await new Promise(r => setTimeout(r, 300))
        const res = await fetch(`http://127.0.0.1:${port}/meeting`, {
          method: 'GET',
          headers: { 'Accept': 'application/json' }
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return await res.json()
      } catch (e) {
        console.warn('GET /meeting falhou', e)
        // Retorna dados de exemplo em caso de erro
        return SAMPLE
      }
    }
  }
})
```

### Registro no Quasar

Adicionar no `quasar.config.js`:

```javascript
boot: [
  'aar-bridge'
]
```

---

## Compilação do Android

### Passo 1: Limpar build anterior

```bash
cd src-capacitor/android
.\gradlew clean
```

### Passo 2: Compilar APK

```bash
.\gradlew assembleDebug
```

### Passo 3: Verificar compilação

O APK será gerado em:
```
src-capacitor/android/app/build/outputs/apk/debug/app-debug.apk
```

### Verificar se as classes foram encontradas

A compilação Java deve passar sem erros. Se houver erro de "classe não encontrada", verifique:
1. O AAR está em `libs/mobileapi.aar`
2. O `build.gradle` inclui o AAR corretamente
3. O nome da classe está correto: `mobileapi.mobileapi.Mobileapi`

---

## Troubleshooting

### Erro: "Classe mobileapi.mobileapi.Mobileapi não encontrada"

**Causas possíveis:**
1. AAR não está na pasta `libs/`
2. `build.gradle` não inclui o AAR
3. Nome da classe incorreto

**Solução:**
```bash
# Verificar se o AAR existe
ls src-capacitor/android/app/libs/mobileapi.aar

# Verificar classes no AAR
cd api/dist
jar -xf mobileapi.aar classes.jar
jar -tf classes.jar | grep Mobileapi
```

### Erro: "AndroidManifest.xml already contains entry"

Este é um aviso conhecido do Gradle ao processar AARs. Não impede o funcionamento do app.

**Solução:**
- Limpar o build: `.\gradlew clean`
- Recompilar: `.\gradlew assembleDebug`

### Erro: "Failed to fetch" ao chamar /meeting

**Causas possíveis:**
1. Servidor não foi iniciado
2. Permissão de tráfego HTTP não configurada
3. Porta incorreta

**Solução:**
1. Verificar `AndroidManifest.xml` tem `android:usesCleartextTraffic="true"`
2. Verificar logs do plugin no Logcat
3. Verificar se `startServer` foi chamado antes de `getMeetingJson`

### Verificar Logs no Android

```bash
# Conectar dispositivo e ver logs
adb logcat | grep -i "RdrMobileApiPlugin\|mobileapi"
```

Logs esperados:
```
I/RdrMobileApiPlugin: Classe mobileapi.mobileapi.Mobileapi carregada com sucesso!
I/RdrMobileApiPlugin: startServer chamado: port=12765, mode=RELEASE
I/RdrMobileApiPlugin: Servidor iniciado com sucesso!
```

---

## Resumo do Fluxo Completo

1. **Desenvolvimento Go**: Criar funções exportadas em `pkg/mobileapi/mobileapi.go`
2. **Compilação**: `gomobile bind -target=android -o dist/mobileapi.aar rdr/scraper/pkg/mobileapi`
3. **Cópia**: Copiar `mobileapi.aar` para `src-capacitor/android/app/libs/`
4. **Configuração Gradle**: Adicionar `implementation(name: 'mobileapi', ext: 'aar')`
5. **Plugin Capacitor**: Criar plugin Java que usa reflection para chamar métodos Go
6. **Bridge JS**: Criar interface JavaScript para o plugin
7. **Compilação Android**: `.\gradlew assembleDebug`
8. **Teste**: Instalar APK e verificar logs

---

## Comandos Rápidos

### Compilar Go para AAR
```bash
cd api
gomobile bind -target=android -o dist/mobileapi.aar rdr/scraper/pkg/mobileapi
```

### Copiar AAR para Android
```bash
Copy-Item -Path "api\dist\mobileapi.aar" -Destination "src-capacitor\android\app\libs\mobileapi.aar" -Force
```

### Compilar Android
```bash
cd src-capacitor/android
.\gradlew clean
.\gradlew assembleDebug
```

### Verificar conteúdo do AAR
```bash
cd api/dist
jar -tf mobileapi.aar
jar -xf mobileapi.aar classes.jar
jar -tf classes.jar | grep Mobileapi
```

---

## Referências

- [gomobile Documentation](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile)
- [Capacitor Android Plugins](https://capacitorjs.com/docs/android/plugins)
- [Android AAR Format](https://developer.android.com/studio/projects/android-library#aar-contents)



