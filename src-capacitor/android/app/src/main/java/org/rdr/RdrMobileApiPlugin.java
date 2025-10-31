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
      // Tente localizar a classe padrão gerada pelo gomobile
      mobileApiClass = Class.forName("mobileapi.Mobileapi");
    } catch (Throwable ignore) {
      // Se o pacote/classe diferir, ajuste aqui conforme seu JAR
      mobileApiClass = null;
    }
  }

  @PluginMethod
  public void startServer(PluginCall call) {
    String port = call.getString("port", DEFAULT_PORT);
    String mode = call.getString("mode", DEFAULT_MODE);
    try {
      if (mobileApiClass == null) throw new IllegalStateException("Classe mobileapi.Mobileapi não encontrada");
      mobileApiClass.getMethod("StartServer", String.class, String.class).invoke(null, port, mode);
      JSObject ret = new JSObject();
      ret.put("port", port);
      call.resolve(ret);
    } catch (Throwable t) {
      Exception ex = (t instanceof Exception) ? (Exception) t : new Exception(t);
      call.reject("Falha ao iniciar servidor: " + ex.getMessage(), ex);
    }
  }

  @PluginMethod
  public void stopServer(PluginCall call) {
    int timeoutMs = call.getInt("timeoutMs", 500);
    try {
      if (mobileApiClass == null) throw new IllegalStateException("Classe mobileapi.Mobileapi não encontrada");
      mobileApiClass.getMethod("StopServer", int.class).invoke(null, timeoutMs);
      call.resolve();
    } catch (Throwable t) {
      Exception ex = (t instanceof Exception) ? (Exception) t : new Exception(t);
      call.reject("Falha ao parar servidor: " + ex.getMessage(), ex);
    }
  }
}


