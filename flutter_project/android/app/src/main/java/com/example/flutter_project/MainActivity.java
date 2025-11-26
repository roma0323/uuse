package com.example.flutter_project;

import io.flutter.embedding.android.FlutterActivity;
import com.google.android.gms.common.GooglePlayServicesNotAvailableException;
import com.google.android.gms.common.GooglePlayServicesRepairableException;
import com.google.android.gms.security.ProviderInstaller;
import android.os.Bundle;
import android.util.Log;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Update security provider to protect against SSL exploits
        try {
            ProviderInstaller.installIfNeeded(getApplicationContext());
            Log.d(TAG, "Security provider updated successfully");
        } catch (GooglePlayServicesRepairableException e) {
            Log.e(TAG, "Google Play Services Repairable Exception", e);
        } catch (GooglePlayServicesNotAvailableException e) {
            Log.e(TAG, "Google Play Services Not Available", e);
        }
    }
}
