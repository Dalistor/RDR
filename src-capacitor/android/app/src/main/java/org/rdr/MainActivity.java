package org.rdr;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        android.util.Log.i("MainActivity", "onCreate iniciado");
        try {
            android.util.Log.i("MainActivity", "Registrando RdrMobileApiPlugin...");
            registerPlugin(RdrMobileApiPlugin.class);
            android.util.Log.i("MainActivity", "RdrMobileApiPlugin registrado!");
        } catch (Exception e) {
            android.util.Log.e("MainActivity", "Erro ao registrar plugin", e);
        }
        super.onCreate(savedInstanceState);
        android.util.Log.i("MainActivity", "onCreate finalizado");
    }
}
