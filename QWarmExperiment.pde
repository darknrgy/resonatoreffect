float dt = 0.000022727272;

class QWarmExperiment extends Experiment {
	final float MIX = 0.1;
	final float freq = 445;
	
	AudioRecorder audioRecorder;

	void setup() {
		audioRecorder = minim.createRecorder(audioOutput, "myrecording.wav");

		FilePlayer fileplayer = new FilePlayer( minim.loadFileStream("music.wav"));
		UGenDSP fileplayerDSP = new UGenDSP(fileplayer, audioOutput);
		fileplayer.loop();

		StereoDSP resonators = new StereoDSP(new ResonatorsDSP(), new ResonatorsDSP());
		resonators.chain(fileplayerDSP.getMultiChannelDSP());

		DSPUGen stereoOut = new DSPUGen(resonators);
		stereoOut.patch(audioOutput);

		audioRecorder.beginRecord();	
	}

	// draw is run many times
	void draw() {
		
		if (millis() > 145000) {
		 	audioRecorder.endRecord();
		 	exit();
		}	
	}
}


