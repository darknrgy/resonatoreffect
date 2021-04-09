import processing.core.PApplet;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
import controlP5.*;

final float MIX = 0.1;
final float freq = 445;
final float tau = 2 * 3.14159;
float dt = 0.000022727272;

// create all of the variables that will need to be accessed in
// more than one methods (setup(), draw(), stop()).
Minim minim;
AudioOutput out;
Constant freqControl;
MixerDSP outputMixer;
MixerDSP synthMixer;
Oscil oscilUGen1;
Oscil oscilUGen2;
GainDSP gain;
UGenDSP oscil1;
UGenDSP oscil2;
DSPUGen outputAdapter;
DSPs resonators;

boolean keyPressed = false;

float[] notes;


float freq0, freq1, freq2;


void setup() {
	size(800, 600, P2D);

	notes = getNoteChart();	
	
	// initialize the minim and out objects
	minim = new Minim(this);
	out = minim.getLineOut(Minim.MONO, 256);

	oscilUGen1 = new Oscil(440, 1, Waves.TRIANGLE);
	oscilUGen2 = new Oscil(440, 1, Waves.TRIANGLE);
	oscil1 = new UGenDSP(oscilUGen1);
	oscil2 = new UGenDSP(oscilUGen2);

	synthMixer = new MixerDSP();
	synthMixer.chain(oscil1);
	//synthMixer.chain(oscil2);

	resonators = new DSPs();
	outputMixer = new MixerDSP();
	for (float resonatorFreq: notes) {
		for (int strings = 0; strings < 5; strings++) {
			ResonatorDSP resonator = new ResonatorDSP(resonatorFreq * random(0.995, 1.005));
			resonator.chain(synthMixer);
			resonator.setMixAmount(0.00005);
			outputMixer.chain(resonator);
		}
	}

	gain = new GainDSP(0.2f);
	gain.chain(outputMixer);

	outputAdapter = new DSPUGen(gain);
	outputAdapter.patch(out);

	ControlP5 cp5 = new ControlP5(this);
	cp5.addSlider("freq0").setPosition(0,200).setRange(0, notes.length -1).setSize(500,30).setValue(10);
	// cp5.addSlider("freq0").setPosition(0,200).setRange(30, 1000).setSize(500,30).setValue(440);
	
}

// draw is run many times
void draw() {
	// erase the window to black
	background( 0 );
	// draw using a white stroke
	stroke( 255 );
	// draw the waveforms
	int trigger = 0;

	for( int i = 0; i < out.bufferSize() - 1; i++ ) {
		// find the x position of each buffer value
		float x1  =  map( i, 0, out.bufferSize(), 0, width );
		float x2  =  map( i+1, 0, out.bufferSize(), 0, width );
		// draw a line from one buffer position to the next for both channels
		line( x1, 50 + out.left.get(i)*50, x2, 50 + out.left.get(i+1)*50);
		line( x1, 150 + out.right.get(i)*50, x2, 150 + out.right.get(i+1)*50);
	}

	oscilUGen1.setFrequency(notes[(int) freq0]);
	oscilUGen2.setFrequency(notes[(int) freq0] * 1.25f);
	// oscilUGen1.setFrequency(freq0);
	if (keyPressed) {
		oscil1.enable();
		oscil2.enable();
	} else {
		oscil1.disable();
		oscil2.disable();
	}
}


void keyPressed() {
	if (keyCode == 65) {
		keyPressed = true;
	}
}

void keyReleased() {
	if (keyCode == 65) {
		keyPressed = false;
	}
}
