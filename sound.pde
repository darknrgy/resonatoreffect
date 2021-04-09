import processing.core.PApplet;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
import controlP5.*;

final float MIX = 0.1;
final float freq = 445;
final float tau = 2 * 3.14159;
float dt = 0.000022727272;


AudioOutput out;
Minim minim;

void setup() {

	size(800, 600, P2D);

	minim = new Minim(this);
	out = minim.getLineOut(Minim.STEREO, 256);

	FilePlayer fileplayer = new FilePlayer( minim.loadFileStream("music.wav"));
	StereoUGenDSP fileplayerDSP = new StereoUGenDSP(fileplayer);
	fileplayer.loop();

	ChannelDSP channelL = new ChannelDSP(fileplayerDSP, 0);
	ChannelDSP channelR = new ChannelDSP(fileplayerDSP, 1);

	ResonatorsDSP resonatorsL = new ResonatorsDSP();
	ResonatorsDSP resonatorsR = new ResonatorsDSP();

	resonatorsL.chain(channelL);
	resonatorsR.chain(channelR);

	StereoDSPUGen stereoOut = new StereoDSPUGen(resonatorsL, resonatorsR);
	stereoOut.patch(out);
	
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
}

