// Similar to Processing's UGen, but allows many to one and one to many relationships

import java.util.ArrayList;

final int bufferSize = 256;

abstract class DSP {
	protected DSPs inputs;
	private float output;
	protected long counter;
	protected boolean enable = true;

	public DSP() {
		inputs = new DSPs();
	}

	abstract protected float generate();

	protected float cascade(long counter) {
		if (!enable) return 0.0f;
		if (counter == this.counter) return output;
		this.counter = counter;
		output = generate();
		return output;
	}

	public void chain(DSP input) {
		inputs.add(input);
	}

	public void chainExclusive(DSP input) {
		inputs = new DSPs();
		inputs.add(input);
	}

	public void chain(DSPs inputs) {
		for (DSP input: inputs) {
			chain(input);
		}
	}

	public float getInput() {
	DSP test = getInputs().get(0);
		return test.cascade(counter);
	}

	public DSPs getInputs() {
		return inputs;
	}

	public void enable() {
		enable = true;
	}

	public void disable() {
		enable = false;
	}
}

class DSPs extends ArrayList<DSP> {}

// UGen to DSP adapter
class UGenDSP extends DSP {
	private UGen ugen;
	public UGenDSP (UGen ugen) {
		this.ugen = ugen;

		// hack to auto configure the UGen
		out = minim.getLineOut(Minim.MONO, bufferSize);
		this.ugen.patch(out);
		this.ugen.unpatch(out);
	}

	public UGen getUGen() {
		return ugen;
	}

	protected float generate() {
		float []channels = new float[1];
		this.ugen.tick(channels);
		return channels[0];
	}
}

// Stereo UGen to DSP adapter
class StereoUGenDSP {
	private UGen ugen;
	private long counter;
	private float[] output = new float[2];

	public StereoUGenDSP (UGen ugen) {
		this.ugen = ugen;

		// hack to auto configure the UGen
		out = minim.getLineOut(Minim.STEREO, bufferSize);
		this.ugen.patch(out);
		this.ugen.unpatch(out);
	}

	protected float generate(long counter, int channel) {
		if (counter == this.counter) return output[channel];
		this.counter = counter;
		this.ugen.tick(output);
		return output[channel];
	}
}

class ChannelDSP extends DSP {
	private int channel;
	private StereoUGenDSP mcDSP;

	public ChannelDSP(StereoUGenDSP mcDSP, int channel) {
		this.channel = channel;
		this.mcDSP = mcDSP;
	}

	protected float generate() {
		return mcDSP.generate(counter, channel);
	}
}

// DSP to UGen adapter
class DSPUGen extends UGen {
	private DSP dsp;
	private long counter = 0;

	public DSPUGen(DSP dsp) {
		this.dsp = dsp;
	}

	protected void uGenerate(float[] channels) {
		channels[0] = dsp.cascade(counter);
		counter ++; 
	}
}

// Stereo DSP to UGen adapter
class StereoDSPUGen extends UGen {
	private DSP dspL;
	private DSP dspR;
	private long counter = 0;

	public StereoDSPUGen(DSP dspL, DSP dspR) {
		this.dspL = dspL;
		this.dspR = dspR;
	}

	protected void uGenerate(float[] channels) {
		channels[0] = dspL.cascade(counter);
		channels[1] = dspR.cascade(counter);
		counter ++; 
	}
}

// https://en.wikipedia.org/wiki/Harmonic_oscillator
class ResonatorDSP extends DSP {
	private float y, v, a, m, mixAmount;
	
	public ResonatorDSP(float freq) {
		y = 0.0f;
		v = 0.0f;
		mixAmount = 0.0f;
		setFrequency(freq);
	}

	public void setFrequency(float freq) {
		float T = 1 / freq;

		a = pow(TWO_PI, 2) / pow(T, 2);
	}

	public void setMixAmount(float mixAmount) {
		this.mixAmount = mixAmount;
	}

	public void chain(DSP input) {
		chainExclusive(input);
	}

	protected float generate() {
		y = y + getInput() * mixAmount;
		v += a * dt * -y;
		y += v * dt;
		y *= 0.99995;
		if (y > 1) y = 1;
		if (y < -1) y = -1;
		return y;
	}
}

// The entire resonator effect as a single module
class ResonatorsDSP extends DSP {
	MixerDSP outputMixer;
	DSPs resonators;
	GainDSP gain;

	public ResonatorsDSP() {
		float[] notes = getNoteChart();
		resonators = new DSPs();
		outputMixer = new MixerDSP();
		gain = new GainDSP(0.01f);
		gain.chain(outputMixer);
		for (float resonatorFreq: notes) {
			for (int strings = 0; strings < 5; strings++) {
				ResonatorDSP resonator = new ResonatorDSP(resonatorFreq * random(0.995, 1.005));
				//ResonatorDSP resonator = new ResonatorDSP(resonatorFreq * random(0.9999, 1.0001));
				resonator.setMixAmount(0.005);
				outputMixer.chain(resonator);
				resonators.add(resonator);
			}
		}
	}

	protected float generate() {
		return gain.cascade(counter);		
	}

	public void chain(DSP input) {
		chainExclusive(input);
		for (DSP resonator: resonators) {
			resonator.chain(input);
		}
	}
}

// Many to one mixer
class MixerDSP extends DSP {
	private float sum;

	protected float generate() {
		sum = 0;
		for (DSP dsp: getInputs()) {
			sum += dsp.cascade(counter);
		}

		return sum;
	}
}

// Gain
class GainDSP extends DSP {
	protected float gain = 1.0f;

	public GainDSP(float gain) {
		setGain(gain);
	}

	public void setGain(float gain) {
		this.gain = gain;
	}

	protected float generate() {
		float y = getInput() * gain;
		if (y > 1) y = 1;
		if (y < -1) y = -1;
		return y;
	}
}
