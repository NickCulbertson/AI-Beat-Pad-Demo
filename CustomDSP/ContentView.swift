import SwiftUI
import AudioKit
import SoundpipeAudioKit

class ContentViewConductor: ObservableObject {
    let engine = AudioEngine()
    var sampler = AppleSampler()
    var effect: LLMEffect
    @Published var bypassEffect = false
    @Published var gainValue: Float = 0 {
        didSet {
            effect.gain = AUValue(gainValue)
        }
    }

    init() {
        effect = LLMEffect(sampler)
        engine.output = effect
        
        do {
            if let url = Bundle.main.url(forResource: "SinePiano", withExtension: "aupreset") {
                try sampler.loadInstrument(at: url)
            } else {
                Log("Could not find SinePiano.aupreset")
            }
        } catch {
            Log("Error loading sampler: \(error)")
        }
        
        try? engine.start()
    }
    
    func startNote(note: MIDINoteNumber) {
        sampler.play(noteNumber: note, velocity: 64)
    }
    
    func stopNote(note: MIDINoteNumber) {
        sampler.stop(noteNumber: note)
    }
    
    func toggleEffect() {
        bypassEffect.toggle()
        if bypassEffect {
            effect.stop()
        } else {
            effect.start()
        }
    }
}

struct ContentView: View {
    @StateObject var conductor = ContentViewConductor()
    let notes: [[MIDINoteNumber]] = [
        [48, 50, 52, 53],    // C3, D3, E3, F3
        [55, 57, 59, 60],    // G3, A3, B3, C4
        [62, 64, 65, 67],    // D4, E4, F4, G4
        [69, 71, 72, 74]     // A4, B4, C5, D5
    ]
    
    // Track which notes are currently being played
    @State private var activeNotes: Set<MIDINoteNumber> = []
    
    var body: some View {
        VStack {
            Button(action: {
                conductor.toggleEffect()
            }, label: {
                Text(conductor.bypassEffect ? "Effect: Bypassed" : "Effect: Enabled")
            })
            .padding()
            
            Slider(value: $conductor.gainValue, in: -25...25, step: 1) {
                Text("Gain")
            }
            .padding()
            
            Text("Gain: \(Int(conductor.gainValue)) dB")
                .padding(.bottom)
            
            // MPC Grid
            VStack(spacing: 10) {
                ForEach(notes.indices.reversed(), id: \.self) { rowIndex in
                    HStack(spacing: 10) {
                        ForEach(notes[rowIndex], id: \.self) { note in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeNotes.contains(note) ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            // Only start the note if it's not already active
                                            if !activeNotes.contains(note) {
                                                conductor.startNote(note: note)
                                                activeNotes.insert(note)
                                            }
                                        }
                                        .onEnded { _ in
                                            // Stop the note when the finger is released
                                            conductor.stopNote(note: note)
                                            activeNotes.remove(note)
                                        }
                                )
                        }
                    }
                }
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
