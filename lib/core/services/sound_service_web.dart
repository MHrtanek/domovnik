// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Plays a short 880 Hz beep via the browser Web Audio API.
void playNotificationSound() {
  try {
    js.context.callMethod('eval', [
      '''(function(){
        var C=window.AudioContext||window.webkitAudioContext;
        if(!C)return;
        var ctx=new C();
        var osc=ctx.createOscillator();
        var gain=ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.type='sine';
        osc.frequency.value=880;
        gain.gain.setValueAtTime(0.2,ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001,ctx.currentTime+0.4);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime+0.4);
      })()'''
    ]);
  } catch (_) {}
}
