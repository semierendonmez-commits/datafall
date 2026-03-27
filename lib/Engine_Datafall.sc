// lib/Engine_Datafall.sc
// datafall v1.2: binary sonification — always stereo buffer
// mono mode writes same data to both channels in WAV

Engine_Datafall : CroneEngine {

  var <buf, <play_synth, <play_group;
  var <out_idx, <play_pos_bus;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    var server = context.server;

    out_idx = context.out_b.index;
    play_group = Group.tail(context.xg);
    play_pos_bus = Bus.control(server, 1);

    SynthDef(\datafall_play, {
      var sig, env, phase, pos_norm, filtered;
      var buf = \buf.kr(0);
      var rate = \rate.kr(0.25);
      var amp = \amp.kr(0.5);
      var gate = \gate.kr(1);
      var lpf_freq = \lpf.kr(8000);
      var lpf_on = \lpf_on.kr(1);
      var loop = \loop.kr(1);
      var out = \out.kr(0);

      sig = PlayBuf.ar(2, buf,
        rate * BufRateScale.kr(buf),
        loop: loop, doneAction: 0);
      sig = LeakDC.ar(sig);

      // LPF with bypass
      filtered = LPF.ar(sig, lpf_freq.clip(100, 18000));
      sig = Select.ar(lpf_on, [sig, filtered]);

      env = EnvGen.kr(Env.asr(0.01, 1, 0.05), gate, doneAction: 2);
      sig = sig * env * amp;

      phase = Phasor.ar(0,
        rate * BufRateScale.kr(buf),
        0, BufFrames.kr(buf));
      pos_norm = A2K.kr(phase) / BufFrames.kr(buf).max(1);
      Out.kr(play_pos_bus.index, pos_norm);

      Out.ar(out, sig);
    }).add;

    SynthDef(\datafall_grain, {
      var sig, env;
      var buf = \buf.kr(0);
      var pos = \pos.kr(0);
      var dur = \dur.kr(0.1);
      var rate = \rate.kr(1);
      var amp = \amp.kr(0.4);
      var out = \out.kr(0);

      sig = PlayBuf.ar(2, buf,
        rate * BufRateScale.kr(buf),
        startPos: pos * BufFrames.kr(buf),
        loop: 0);
      sig = LeakDC.ar(sig);
      sig = LPF.ar(sig, 6000);
      env = EnvGen.kr(
        Env.linen(0.005, (dur - 0.01).max(0.001), 0.005),
        doneAction: 2);
      sig = sig * env * amp;
      Out.ar(out, sig);
    }).add;

    server.sync;

    this.addCommand("load_file", "s", { |msg|
      var path = msg[1].asString;
      if(buf.notNil, { buf.free });
      Buffer.read(server, path, action: { |b|
        buf = b;
        ("datafall: loaded " ++ b.numFrames ++ " frames, " ++ b.numChannels ++ "ch").postln;
      });
    });

    this.addCommand("play", "ff", { |msg|
      if(play_synth.notNil, {
        play_synth.set(\gate, 0); play_synth = nil;
      });
      if(buf.notNil, {
        play_synth = Synth(\datafall_play, [
          \buf, buf, \rate, msg[1], \amp, msg[2],
          \out, out_idx, \loop, 1
        ], play_group, \addToTail);
      });
    });

    this.addCommand("stop", "", { |msg|
      if(play_synth.notNil, {
        play_synth.set(\gate, 0); play_synth = nil;
      });
    });

    this.addCommand("rate", "f", { |msg|
      if(play_synth.notNil, { play_synth.set(\rate, msg[1]) });
    });

    this.addCommand("amp", "f", { |msg|
      if(play_synth.notNil, { play_synth.set(\amp, msg[1]) });
    });

    this.addCommand("lpf", "f", { |msg|
      if(play_synth.notNil, { play_synth.set(\lpf, msg[1]) });
    });

    this.addCommand("lpf_on", "f", { |msg|
      if(play_synth.notNil, { play_synth.set(\lpf_on, msg[1]) });
    });

    this.addCommand("loop_mode", "f", { |msg|
      if(play_synth.notNil, { play_synth.set(\loop, msg[1]) });
    });

    this.addCommand("grain", "fff", { |msg|
      if(buf.notNil, {
        Synth(\datafall_grain, [
          \buf, buf, \pos, msg[1], \dur, msg[2],
          \amp, msg[3], \rate, 0.5, \out, out_idx
        ], play_group, \addToTail);
      });
    });

    this.addPoll("play_pos", { play_pos_bus.getSynchronous });

    ("Engine_Datafall v1.2: stereo sonification ready.").postln;
  }

  free {
    if(play_synth.notNil, { play_synth.free });
    if(buf.notNil, { buf.free });
    play_pos_bus.free;
    play_group.free;
  }
}
