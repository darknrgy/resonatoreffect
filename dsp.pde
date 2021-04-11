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

class MultiChannelDSP {
	DSPs dsps;

	public MultiChannelDSP() {}
	
	public MultiChannelDSP(DSP dsp) {
		this.dsps = new DSPs();
		this.dsps.add(dsp);
	}

	public MultiChannelDSP(DSPs dsps) {
		this.dsps = dsps;
	}

	protected int channelCount() {
		return dsps.size();
	}

	protected DSPs getDSPs() {
		return dsps;
	}

	protected DSP getDSP(int channel) {
		return dsps.get(channel);
	}

	public void chain(MultiChannelDSP input) {
		if (input.channelCount() != dsps.size()) {
			error("Channel count mismatch in MultiChannelDSP");
		}

		for (int i = 0; i < dsps.size(); i++) {
			dsps.get(i).chain(input.getDSPs().get(i));
		}
	}
}

class StereoDSP extends MultiChannelDSP {
	public StereoDSP(DSP dspL, DSP dspR) {
		super();
		dsps = new DSPs();
		dsps.add(dspL);
		dsps.add(dspR);
	}
}

// UGen to DSP adapter
class UGenDSP {
	protected UGen ugen;
	protected long counter;
	protected MultiChannelDSP dsps;
	
	float[] output;

	public UGenDSP (UGen ugen, AudioOutput audioOuptut) {
		this.ugen = ugen;

		// hack to auto configure the UGen
		this.ugen.patch(audioOuptut);
		this.ugen.unpatch(audioOuptut);

		DSPs dsps = new DSPs();
		for (int i = 0; i < ugen.channelCount(); i++) {
			dsps.add(new ChannelDSP(this, i));
		}

		this.dsps = new MultiChannelDSP(dsps);
		output = new float[ugen.channelCount()];
	}

	public MultiChannelDSP getMultiChannelDSP() {
		return dsps;
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
	private UGenDSP uGenDSP;

	public ChannelDSP(UGenDSP uGenDSP, int channel) {
		this.channel = channel;
		this.uGenDSP = uGenDSP;
	}
	
	protected float generate() {
		return uGenDSP.generate(counter, channel);
	}
}
// DSP  to uGen adapter
class DSPUGen extends UGen {
	protected MultiChannelDSP dsps;
	protected int counter;

	public DSPUGen(DSP dsp) {
		this.dsps = new MultiChannelDSP(dsp);		
	}

	public DSPUGen(DSP dspL, DSP dspR) {
		this.dsps = new StereoDSP(dspL, dspR);
	}

	public DSPUGen(DSPs dsps) {
		this.dsps = new MultiChannelDSP(dsps);
	}

	public DSPUGen(MultiChannelDSP mcdsp) {
		this.dsps = mcdsp;
	}

	protected void uGenerate(float[] channels) {
		
		if (channels.length != dsps.channelCount()) {
			error("Channel mismatch in DSPUGen");
		}

		for (int i = 0; i < channels.length; i++) {
			channels[i] = dsps.getDSP(i).cascade(counter);
		}

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
		y *= 0.9999;
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
		gain = new GainDSP(0.04f);
		gain.chain(outputMixer);
		for (float resonatorFreq: notes) {
			for (int strings = 0; strings < 5; strings++) {
				ResonatorDSP resonator = new ResonatorDSP(resonatorFreq * random(0.995, 1.005));
				//ResonatorDSP resonator = new ResonatorDSP(resonatorFreq * random(0.9999, 1.0001));
				resonator.setMixAmount(0.001);
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

class CompressorDSP extends DSP {
	float compression;

	public void setCompression(float compression) {
		this.compression = map(compression, 0, 1, 2, 0);
		print (this.compression + "\n");
	}

	protected float generate() {
		float input = getInput();
		return pow(abs(input), compression) * (input > 0 ? 1 : -1);
	}
}

void error(String message) {
	print ("Error: " + message + "\n");
	exit();
}