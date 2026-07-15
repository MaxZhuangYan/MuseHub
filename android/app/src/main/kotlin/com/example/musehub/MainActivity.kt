package com.example.musehub

import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity (instead of FlutterActivity) so
// just_audio_background can drive the media-session notification and
// lock-screen / headset controls.
class MainActivity : AudioServiceActivity()
