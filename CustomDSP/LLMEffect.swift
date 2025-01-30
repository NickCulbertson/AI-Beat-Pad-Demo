import AudioKit
import AudioKitEX
import AVFoundation
import CAudioKitEX

/// LoFi Effect
public class LLMEffect: Node {
    let input: Node

    /// Connected nodes
    public var connections: [Node] { [input] }

    /// Underlying AVAudioNode
    public var avAudioNode = instantiate(effect: "lofs")

    // MARK: - Parameters

    /// Gain parameter definition
    public static let gainDef = NodeParameterDef(
        identifier: "gain",
        name: "Gain",
        address: akGetParameterAddress("LoFiParameterGain"),
        defaultValue: 0,
        range: -25 ... 25,
        unit: .generic
    )

    @Parameter(gainDef) public var gain: AUValue

    // MARK: - Initialization

    public init(
        _ input: Node,
        gain: AUValue = gainDef.defaultValue
    ) {
        self.input = input
        setupParameters()
        self.gain = gain
    }
}
