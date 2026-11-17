// Cluck Crossing sound generator.
// Synthesises every sound effect and the two music loops as 16-bit mono WAV files.
// Deterministic: noise uses a fixed seed. Usage: swift generate_sounds.swift "<output dir>"

import Foundation

let rate = 44_100.0
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Sounds")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var noiseState: UInt64 = 0x1234_5678
func noise() -> Double {
    noiseState ^= noiseState << 13; noiseState ^= noiseState >> 7; noiseState ^= noiseState << 17
    return Double(noiseState % 20_000) / 10_000 - 1
}

struct Buffer {
    var s: [Double]
    init(_ seconds: Double) { s = Array(repeating: 0, count: Int(seconds * rate)) }
    var count: Int { s.count }
    mutating func add(_ other: Buffer, at t: Double, gain: Double = 1) {
        let o = Int(t * rate)
        for i in 0..<other.count where o + i < count && o + i >= 0 { s[o + i] += other.s[i] * gain }
    }
}

enum Wave { case sine, square, saw, triangle, noise }
func osc(_ w: Wave, _ phase: Double) -> Double {
    let p = phase - floor(phase)
    switch w {
    case .sine: return sin(p * 2 * .pi)
    case .square: return p < 0.5 ? 1 : -1
    case .saw: return 2 * p - 1
    case .triangle: return 4 * abs(p - 0.5) - 1
    case .noise: return noise()
    }
}

/// A tone whose frequency glides from f0 to f1, shaped by an attack/decay envelope.
func tone(_ w: Wave, _ f0: Double, _ f1: Double, _ dur: Double, attack: Double = 0.005, decay: Double? = nil, vibrato: Double = 0, vibRate: Double = 6, curve: Double = 1) -> Buffer {
    var b = Buffer(dur)
    var phase = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let k = pow(t / dur, curve)
        let f = f0 + (f1 - f0) * k + vibrato * sin(2 * .pi * vibRate * t)
        phase += f / rate
        let env: Double
        if t < attack { env = t / attack } else {
            let d = decay ?? (dur - attack)
            env = max(0, 1 - (t - attack) / d)
        }
        b.s[i] = osc(w, phase) * env * env
    }
    return b
}
func noiseBurst(_ dur: Double, attack: Double = 0.003, lowpass: Double = 1, highpass: Double = 0, curve: Double = 2) -> Buffer {
    var b = Buffer(dur)
    var lp = 0.0, hpPrev = 0.0, hpOut = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let env = t < attack ? t / attack : pow(max(0, 1 - (t - attack) / (dur - attack)), curve)
        let n = noise()
        lp += (n - lp) * lowpass
        hpOut = highpass > 0 ? highpass * (hpOut + lp - hpPrev) : lp
        hpPrev = lp
        b.s[i] = hpOut * env
    }
    return b
}
func lowpass(_ b: inout Buffer, _ a: Double) { var y = 0.0; for i in 0..<b.count { y += (b.s[i] - y) * a; b.s[i] = y } }

func write(_ name: String, _ b: Buffer, gain: Double = 0.8) {
    let peak = max(0.0001, b.s.map { abs($0) }.max() ?? 1)
    let scale = gain / peak
    var data = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
    let bytes = UInt32(b.count * 2)
    data.append("RIFF".data(using: .ascii)!); u32(36 + bytes); data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
    data.append("data".data(using: .ascii)!); u32(bytes)
    for v in b.s { var x = Int16(max(-1, min(1, v * scale)) * 32_000).littleEndian; data.append(Data(bytes: &x, count: 2)) }
    try! data.write(to: outDir.appendingPathComponent("\(name).wav"))
}

// MARK: - Effects

do { // Hop: soft scratchy step + tiny chirp.
    var b = Buffer(0.12)
    b.add(noiseBurst(0.05, lowpass: 0.5, highpass: 0.7), at: 0, gain: 0.5)
    b.add(tone(.sine, 1400, 1900, 0.06, attack: 0.002, curve: 0.5), at: 0.01, gain: 0.35)
    write("sfx_hop", b, gain: 0.5)
}
do { // Cluck: two buzzy square bursts.
    var b = Buffer(0.3)
    for (t, f) in [(0.0, 620.0), (0.12, 760.0)] {
        var c = tone(.square, f, f * 0.6, 0.1, attack: 0.004, vibrato: 50, vibRate: 80)
        lowpass(&c, 0.22)
        b.add(c, at: t, gain: 0.7)
    }
    write("sfx_cluck", b, gain: 0.6)
}
do { // Lane scored: neon blip.
    var b = tone(.triangle, 1046.5, 1568, 0.09, attack: 0.002, curve: 0.4)
    b.add(tone(.sine, 2093, 2093, 0.05, attack: 0.002), at: 0.03, gain: 0.25)
    write("sfx_score", b, gain: 0.4)
}
do { // Roost: eggs settle into the nest — warm chord.
    var b = Buffer(0.8)
    for (i, f) in [523.25, 659.25, 783.99, 1046.5].enumerated() {
        b.add(tone(.triangle, f, f, 0.6, attack: 0.01), at: Double(i) * 0.05, gain: 0.4)
    }
    b.add(noiseBurst(0.15, lowpass: 0.2), at: 0, gain: 0.2)
    write("sfx_roost", b, gain: 0.6)
}
for (i, f) in [1250.0].enumerated() {
    var b = tone(.sine, f, f * 1.45, 0.09, attack: 0.002)
    b.add(tone(.triangle, f * 2, f * 2.9, 0.06, attack: 0.002), at: 0, gain: 0.3)
    _ = i
    write("sfx_kernel", b, gain: 0.5)
}
do { // Crossing-guard whistle: trilled high tone.
    var w = tone(.sine, 2900, 3000, 0.55, attack: 0.01, decay: 0.7, vibrato: 140, vibRate: 32)
    w.add(noiseBurst(0.55, attack: 0.02, lowpass: 0.9, highpass: 0.9, curve: 1), at: 0, gain: 0.08)
    write("sfx_whistle", w, gain: 0.45)
}
do { // Truck horn: low two-tone.
    var b = Buffer(0.7)
    for f in [196.0, 247.0] { var h = tone(.saw, f, f, 0.65, attack: 0.02, decay: 0.9); lowpass(&h, 0.08); b.add(h, at: 0, gain: 0.5) }
    write("sfx_honk", b, gain: 0.6)
}
do { // Manhole flare: whoomph.
    var b = noiseBurst(0.6, attack: 0.04, lowpass: 0.12, curve: 1.6)
    b.add(tone(.sine, 90, 50, 0.4, attack: 0.01), at: 0, gain: 0.8)
    write("sfx_flare", b, gain: 0.7)
}
do { // Bump: thump + squawk.
    var b = Buffer(0.6)
    b.add(tone(.sine, 120, 40, 0.3, attack: 0.002), at: 0, gain: 1)
    b.add(noiseBurst(0.25, lowpass: 0.4, curve: 3), at: 0, gain: 0.6)
    var sq = tone(.square, 900, 500, 0.25, attack: 0.005, vibrato: 60, vibRate: 40)
    lowpass(&sq, 0.3)
    b.add(sq, at: 0.08, gain: 0.4)
    write("sfx_bump", b, gain: 0.8)
}
do { var b = tone(.sine, 1200, 900, 0.035, attack: 0.001); b.add(noiseBurst(0.02, lowpass: 0.8), at: 0, gain: 0.3); write("sfx_tap", b, gain: 0.35) }
do { // Vending clunk + coin sparkle.
    var b = Buffer(0.6)
    b.add(tone(.sine, 140, 70, 0.15, attack: 0.002), at: 0, gain: 0.8)
    for (i, f) in [1568.0, 2093, 2637].enumerated() { b.add(tone(.sine, f, f, 0.25, attack: 0.002), at: 0.12 + Double(i) * 0.06, gain: 0.4) }
    write("sfx_buy", b, gain: 0.5)
}
do { write("sfx_star", tone(.triangle, 1318.5, 1975, 0.4, attack: 0.003, curve: 0.3), gain: 0.5) }
do { write("sfx_count", tone(.square, 440, 440, 0.12, attack: 0.004), gain: 0.3) }
do { var b = tone(.square, 880, 880, 0.3, attack: 0.004); lowpass(&b, 0.35); write("sfx_go", b, gain: 0.4) }
do { // Finish: jazzy neon fanfare.
    var b = Buffer(1.3)
    let notes: [(Double, Double, Double)] = [(0, 523.25, 0.14), (0.15, 622.25, 0.14), (0.3, 783.99, 0.14), (0.45, 932.33, 0.7)]
    for (t, f, d) in notes { var n = tone(.square, f, f, d, attack: 0.004); lowpass(&n, 0.3); b.add(n, at: t, gain: 0.45); b.add(tone(.triangle, f / 2, f / 2, d, attack: 0.004), at: t, gain: 0.3) }
    write("sfx_finish", b, gain: 0.6)
}
do { // Game over: descending wah.
    var b = Buffer(1.3)
    for (i, f) in [392.0, 370, 349.2, 329.6].enumerated() {
        var n = tone(.saw, f, f * (i == 3 ? 0.92 : 1), i == 3 ? 0.6 : 0.26, attack: 0.02, vibrato: i == 3 ? 6 : 0, vibRate: 5)
        lowpass(&n, 0.1)
        b.add(n, at: Double(i) * 0.26, gain: 0.6)
    }
    write("sfx_gameover", b, gain: 0.6)
}

// MARK: - Music loops

func midi(_ n: Int) -> Double { 440 * pow(2, Double(n - 69) / 12) }

/// Renders a loop of `bars` bars; notes past the end wrap to the start so the loop is seamless.
func renderLoop(bpm: Double, bars: Int, lead: [(Double, Int, Double)], bass: [(Double, Int, Double)], hats: Bool, leadWave: Wave, gain: Double) -> Buffer {
    let beat = 60 / bpm
    let total = beat * 4 * Double(bars)
    var b = Buffer(total)
    func place(_ n: Buffer, _ t: Double, _ g: Double) {
        let o = Int(t * rate)
        for i in 0..<n.count { b.s[(o + i) % b.count] += n.s[i] * g }
    }
    for (beatPos, note, len) in lead {
        var n = tone(leadWave, midi(note), midi(note), len * beat * 0.95, attack: 0.006, decay: len * beat * 1.4, vibrato: midi(note) * 0.004, vibRate: 5.5)
        lowpass(&n, 0.35)
        place(n, beatPos * beat, 0.32)
    }
    for (beatPos, note, len) in bass {
        place(tone(.triangle, midi(note), midi(note), len * beat * 0.9, attack: 0.004, decay: len * beat), beatPos * beat, 0.5)
    }
    let beats = bars * 4
    for k in 0..<beats {
        place(tone(.sine, 110, 45, 0.12, attack: 0.002), Double(k) * beat, k % 2 == 0 ? 0.55 : 0.0)
        if hats {
            place(noiseBurst(0.04, lowpass: 0.9, highpass: 0.95, curve: 3), (Double(k) + 0.5) * beat, 0.16)
            if k % 2 == 1 { place(noiseBurst(0.12, lowpass: 0.5, highpass: 0.6, curve: 2), Double(k) * beat, 0.3) }
        }
    }
    _ = gain
    return b
}

do { // Run loop: night-drive pulse, 8 bars at 140 bpm in A minor.
    let prog = [45, 45, 41, 41, 43, 43, 40, 40] // Am Am F F G G E E (night drive)
    var bass: [(Double, Int, Double)] = []
    for (bar, root) in prog.enumerated() { for k in 0..<4 { bass.append((Double(bar * 4 + k), root + (k % 2 == 1 ? 7 : 0), 0.9)) } }
    let phrase: [(Double, Int, Double)] = [
        (0, 69, 0.5), (0.5, 72, 0.5), (1, 76, 1), (2, 74, 0.5), (2.5, 72, 0.5), (3, 69, 1),
        (4, 72, 0.5), (4.5, 76, 0.5), (5, 77, 1), (6, 76, 0.5), (6.5, 74, 0.5), (7, 72, 1),
        (8, 74, 0.75), (8.75, 74, 0.25), (9, 79, 0.5), (9.5, 77, 0.5), (10, 76, 1), (11, 74, 1),
        (12, 71, 0.5), (12.5, 74, 0.5), (13, 76, 0.5), (13.5, 80, 0.5), (14, 76, 1), (15, 71, 1),
    ]
    let lead = phrase + phrase.map { ($0.0 + 16, $0.1, $0.2) }
    write("music_run", renderLoop(bpm: 140, bars: 8, lead: lead, bass: bass, hats: true, leadWave: .square, gain: 1), gain: 0.55)
}
do { // Menu loop: late-night lounge, 8 bars at 100 bpm.
    let prog = [45, 50, 43, 48, 45, 50, 52, 52] // Am Dm G C Am Dm E E (lounge)
    var bass: [(Double, Int, Double)] = []
    for (bar, root) in prog.enumerated() { bass.append((Double(bar * 4), root, 1.4)); bass.append((Double(bar * 4 + 2), root + 7, 1.4)) }
    let lead: [(Double, Int, Double)] = [
        (0, 76, 1.5), (1.5, 74, 0.5), (2, 72, 2), (4, 77, 1), (5, 74, 1), (6, 72, 2),
        (8, 74, 1.5), (9.5, 72, 0.5), (10, 71, 2), (12, 72, 1), (13, 74, 1), (14, 76, 2),
        (16, 76, 1.5), (17.5, 74, 0.5), (18, 72, 2), (20, 77, 1), (21, 76, 1), (22, 74, 2),
        (24, 76, 1.5), (25.5, 74, 0.5), (26, 71, 1), (27, 68, 1), (28, 71, 2), (30, 69, 2),
    ]
    write("music_menu", renderLoop(bpm: 100, bars: 8, lead: lead, bass: bass, hats: false, leadWave: .triangle, gain: 1), gain: 0.5)
}
print("Sounds written to \(outDir.path)")
