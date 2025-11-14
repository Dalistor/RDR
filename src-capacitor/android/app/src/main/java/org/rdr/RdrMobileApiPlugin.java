package org.rdr;

import com.getcapacitor.Bridge;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.PluginMethod;

@CapacitorPlugin(name = "RdrMobileApiPlugin")
public class RdrMobileApiPlugin extends Plugin {

  // Porta padrão do servidor embutido
  private static final String DEFAULT_PORT = "12765";
  private static final String DEFAULT_MODE = "RELEASE";

  // Referência para a classe do JAR gerado pelo gomobile (ajuste se o pacote/classe for diferente)
  // Ex.: package mobileapi; public final class Mobileapi { public static void StartServer(String port, String mode) ... }
  private Class<?> mobileApiClass;

  @Override
  public void load() {
    super.load();
    try {
      // Tenta primeiro o pacote simples (mobileapi.Mobileapi)
      try {
        mobileApiClass = Class.forName("mobileapi.Mobileapi");
        android.util.Log.i("RdrMobileApiPlugin", "Classe mobileapi.Mobileapi carregada (pacote simples)!");
      } catch (ClassNotFoundException e1) {
        // Fallback para pacote duplo (mobileapi.mobileapi.Mobileapi)
        try {
          mobileApiClass = Class.forName("mobileapi.mobileapi.Mobileapi");
          android.util.Log.i("RdrMobileApiPlugin", "Classe mobileapi.mobileapi.Mobileapi carregada (pacote duplo)!");
        } catch (ClassNotFoundException e2) {
          throw new ClassNotFoundException("Classe Mobileapi não encontrada em nenhum pacote", e2);
        }
      }
    } catch (Throwable e) {
      android.util.Log.e("RdrMobileApiPlugin", "Falha ao carregar classe: " + e.getMessage());
      // Se o pacote/classe diferir, ajuste aqui conforme seu JAR
      mobileApiClass = null;
    }
  }

  @PluginMethod
  public void startServer(PluginCall call) {
    String port = call.getString("port", DEFAULT_PORT);
    String mode = call.getString("mode", DEFAULT_MODE);
    android.util.Log.i("RdrMobileApiPlugin", "startServer chamado: port=" + port + ", mode=" + mode);
    try {
      if (mobileApiClass == null) {
        android.util.Log.e("RdrMobileApiPlugin", "mobileApiClass é null!");
        throw new IllegalStateException("Classe mobileapi.Mobileapi não encontrada no JAR");
      }
      android.util.Log.i("RdrMobileApiPlugin", "Invocando StartServer...");
      try {
        // Tenta com S maiúsculo primeiro (padrão Go)
        mobileApiClass.getMethod("StartServer", String.class, String.class).invoke(null, port, mode);
      } catch (NoSuchMethodException e) {
        // Se não encontrar, tenta com s minúsculo
        android.util.Log.w("RdrMobileApiPlugin", "StartServer não encontrado, tentando startServer");
        mobileApiClass.getMethod("startServer", String.class, String.class).invoke(null, port, mode);
      }
      android.util.Log.i("RdrMobileApiPlugin", "Servidor iniciado com sucesso!");
      JSObject ret = new JSObject();
      ret.put("port", port);
      call.resolve(ret);
    } catch (Throwable t) {
      android.util.Log.e("RdrMobileApiPlugin", "Erro ao iniciar servidor", t);
      Exception ex = (t instanceof Exception) ? (Exception) t : new Exception(t);
      call.reject("Falha ao iniciar servidor: " + ex.getMessage(), ex);
    }
  }

  @PluginMethod
  public void stopServer(PluginCall call) {
    int timeoutMs = call.getInt("timeoutMs", 500);
    android.util.Log.i("RdrMobileApiPlugin", "stopServer chamado: timeoutMs=" + timeoutMs);
    try {
      if (mobileApiClass == null) {
        android.util.Log.e("RdrMobileApiPlugin", "mobileApiClass é null!");
        throw new IllegalStateException("Classe mobileapi.Mobileapi não encontrada");
      }
      
      // Lista todos os métodos disponíveis para debug
      android.util.Log.i("RdrMobileApiPlugin", "Métodos disponíveis na classe:");
      for (java.lang.reflect.Method m : mobileApiClass.getMethods()) {
        if (m.getName().toLowerCase().contains("stop")) {
          android.util.Log.i("RdrMobileApiPlugin", "  - " + m.getName() + "(" + 
            java.util.Arrays.toString(m.getParameterTypes()) + ")");
        }
      }
      
      try {
        // O gomobile converte int do Go para long em Java
        android.util.Log.i("RdrMobileApiPlugin", "Tentando stopServer(long.class)...");
        mobileApiClass.getMethod("stopServer", long.class).invoke(null, (long)timeoutMs);
        android.util.Log.i("RdrMobileApiPlugin", "stopServer(long.class) executado com sucesso!");
      } catch (NoSuchMethodException e) {
        android.util.Log.e("RdrMobileApiPlugin", "stopServer não encontrado mesmo com long.class", e);
        throw e;
      }
      android.util.Log.i("RdrMobileApiPlugin", "Servidor parado com sucesso!");
      call.resolve();
    } catch (Throwable t) {
      android.util.Log.e("RdrMobileApiPlugin", "Erro ao parar servidor", t);
      Exception ex = (t instanceof Exception) ? (Exception) t : new Exception(t);
      call.reject("Falha ao parar servidor: " + ex.getMessage(), ex);
    }
  }
}


