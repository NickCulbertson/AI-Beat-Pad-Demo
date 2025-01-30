#include "SoundpipeDSPBase.h"
#include "ParameterRamper.h"
#include "Soundpipe.h"
#include <vector>

enum LoFiParameter : AUParameterAddress {
    LoFiParameterGain,
};

class LoFiDSP : public SoundpipeDSPBase {
private:
    ParameterRamper gainRamp;
    sp_butlp *lowpass;        // Low-pass filter
    sp_vdelay *vdelay;        // Variable delay for pitch wobble
    sp_osc *lfo;              // LFO for modulation
    sp_ftbl *lfoTable;        // Wavetable for the LFO
    std::vector<float> wavetable;

public:
    LoFiDSP() {
        // Register the gain parameter
        parameters[LoFiParameterGain] = &gainRamp;
    }

    void init(int channelCount, double sampleRate) override {
        SoundpipeDSPBase::init(channelCount, sampleRate);
        gainRamp.init();
        gainRamp.setUIValue(0.0f); // Default gain value (0 dB)

        // Initialize low-pass filter
        sp_butlp_create(&lowpass);
        sp_butlp_init(sp, lowpass);
        lowpass->freq = 800.0f; // Set initial cutoff frequency

        // Initialize variable delay for pitch wobble
        sp_vdelay_create(&vdelay);
        sp_vdelay_init(sp, vdelay, 1.0); // Max delay time of 1 second
        vdelay->del = 0.01f;             // Initial delay time

        // Initialize LFO
        wavetable = std::vector<float>(2048, 0.0f);
        sp_ftbl_create(sp, &lfoTable, wavetable.size());
        sp_gen_sine(sp, lfoTable); // Generate sine wave for LFO

        sp_osc_create(&lfo);
        sp_osc_init(sp, lfo, lfoTable, 0);
        lfo->freq = 0.25f; // LFO frequency
        lfo->amp = 0.005f; // LFO amplitude
    }

    void deinit() override {
        SoundpipeDSPBase::deinit();

        // Destroy resources
        sp_butlp_destroy(&lowpass);
        sp_vdelay_destroy(&vdelay);
        sp_osc_destroy(&lfo);
        sp_ftbl_destroy(&lfoTable);
    }

    void reset() override {
        SoundpipeDSPBase::reset();
    }

    void process(FrameRange range) override {
        for (int i : range) {
            float gainDb = gainRamp.getAndStep();
            float gainLinear = powf(10.0f, gainDb / 20.0f); // Convert dB to linear gain

            // Generate the LFO signal for wobble
            float lfoValue;
            float dummyInput = 0.0f;
            sp_osc_compute(sp, lfo, &dummyInput, &lfoValue);

            // Modulate delay time
            vdelay->del = 0.01f + lfoValue; // Base delay of 10ms modulated by LFO

            for (int channel = 0; channel < channelCount; ++channel) {
                float input = inputSample(channel, i);
                float &output = outputSample(channel, i);

                // Apply gain
                float processedSample = input * gainLinear;

                // Apply low-pass filter
                float filteredSample;
                sp_butlp_compute(sp, lowpass, &processedSample, &filteredSample);

                // Apply delay for pitch wobble
                float wobbledSample;
                sp_vdelay_compute(sp, vdelay, &filteredSample, &wobbledSample);

                output = wobbledSample;
            }
        }
    }
};

AK_REGISTER_DSP(LoFiDSP, "lofs")
AK_REGISTER_PARAMETER(LoFiParameterGain)
