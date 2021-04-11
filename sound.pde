import processing.core.PApplet;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
import controlP5.*;

AudioOutput audioOutput;
Minim minim;
Experiment experiment;

void setup() {
	size(800, 600, P2D);
	minim = new Minim(this);
	audioOutput = minim.getLineOut(Minim.STEREO, 1024);
	experiment = new QWarmExperiment();
	experiment.setup();
}

// draw is run many times
void draw() {

	// erase the window to black
	background( 0 );
	// draw using a white stroke
	stroke( 255 );
	// draw the waveforms
	int trigger = 0;

	for( int i = 0; i < audioOutput.bufferSize() - 1; i++ ) {
		// find the x position of each buffer value
		float x1  =  map( i, 0, audioOutput.bufferSize(), 0, width );
		float x2  =  map( i+1, 0, audioOutput.bufferSize(), 0, width );
		// draw a line from one buffer position to the next for both channels
		line( x1, 50 + audioOutput.left.get(i)*50, x2, 50 + audioOutput.left.get(i+1)*50);
		line( x1, 150 + audioOutput.right.get(i)*50, x2, 150 + audioOutput.right.get(i+1)*50);
	}

	experiment.draw();
}

