package com.norns.omnitune

import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : AudioServiceActivity() {
    override fun getRenderMode(): RenderMode {
        // On ranchu (Android emulator QEMU GLES), SurfaceView blocks in eglSwapBuffers/dequeueBuffer
        // during active lyric animations. Fall back to TextureView only on verified ranchu hardware.
        return if (Build.HARDWARE == "ranchu") {
            RenderMode.texture
        } else {
            super.getRenderMode()
        }
    }
}
