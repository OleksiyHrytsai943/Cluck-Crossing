import SpriteKit
import UIKit

/// Renders the road and handles touches. All rules live in `RunSession`.
final class CrossingScene: SKScene {
    private weak var viewModel: GameViewModel?
    private var session: RunSession { viewModel?.session ?? RunSession(config: RunConfig(mode: .longRoad)) }

    private let world = SKNode()
    private var cell: CGFloat = 75
    private var camY: CGFloat = 0
    private var lastTime: TimeInterval?
    private var snapshotClock = 0.0

    private var rowNodes: [Int: RowNode] = [:]
    private var carNodes: [CarKey: SKSpriteNode] = [:]
    private var kernelNodes: [CarKey: SKSpriteNode] = [:]
    private let hen = SKSpriteNode()
    private var henFacingLeft = false
    private var lastColumn = RunConfig.columns / 2
    private var fog = false
    private let flash = SKSpriteNode(color: .red, size: .zero)

    private var touchStart: CGPoint?

    private struct CarKey: Hashable {
        let row: Int
        let id: Int
    }

    /// Visual parts of one road row.
    private final class RowNode: SKNode {
        let background = SKSpriteNode()
        var plaque: SKSpriteNode?
        var plaqueLabel: SKLabelNode?
        var frozen: SKSpriteNode?
        var rush: SKSpriteNode?
        var honk: SKLabelNode?
        var lid: SKSpriteNode?
        var spray: SKSpriteNode?
        var lastMultiplier: Double?
    }

    private static let softDot: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                             endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
        return SKTexture(image: image)
    }()

    private static let ink = UIColor(red: 0.17, green: 0.10, blue: 0.06, alpha: 1)

    private static let pickupTints: [UIColor] = [
        UIColor(red: 0.95, green: 0.35, blue: 0.40, alpha: 1),
        UIColor(red: 0.40, green: 0.60, blue: 1.00, alpha: 1),
        UIColor(red: 0.75, green: 0.75, blue: 0.80, alpha: 1),
        UIColor(red: 0.55, green: 0.85, blue: 0.45, alpha: 1),
        UIColor(red: 0.85, green: 0.55, blue: 1.00, alpha: 1),
    ]

    init(size: CGSize, viewModel: GameViewModel) {
        self.viewModel = viewModel
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.42, green: 0.66, blue: 0.27, alpha: 1)
        if case .crossing(let index) = viewModel.mode { fog = CrossingSpec.all[index].hazards.fog }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        guard world.parent == nil else { return }
        addChild(world)
        hen.zPosition = 50
        world.addChild(hen)
        flash.zPosition = 500
        flash.alpha = 0
        flash.anchorPoint = .zero
        addChild(flash)
        layout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layout()
    }

    private func layout() {
        guard size.width > 0 else { return }
        cell = size.width / CGFloat(RunConfig.columns)
        flash.size = size
        for (_, node) in rowNodes { node.removeFromParent() }
        rowNodes.removeAll()
        for (_, node) in carNodes { node.removeFromParent() }
        carNodes.removeAll()
        for (_, node) in kernelNodes { node.removeFromParent() }
        kernelNodes.removeAll()
        hen.texture = SKTexture(imageNamed: viewModel?.store.hen.art ?? "hen_pepper")
        hen.size = CGSize(width: cell * 0.95, height: cell * 0.95)
        hen.position = henTarget
        camY = cameraTarget
        world.position.y = -camY
    }

    /// New run on the same scene (Try again).
    func reset() {
        if let mode = viewModel?.mode, case .crossing(let index) = mode {
            fog = CrossingSpec.all[index].hazards.fog
        } else {
            fog = false
        }
        hen.removeAllActions()
        hen.zRotation = 0
        hen.alpha = 1
        lastColumn = RunConfig.columns / 2
        layout()
    }

    // MARK: Geometry

    private func center(row: Int, column: Int) -> CGPoint {
        CGPoint(x: (CGFloat(column) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
    }

    private var henTarget: CGPoint {
        var p = center(row: session.row, column: session.column)
        p.y += cell * 0.08
        return p
    }

    /// Keeps the hen at 30% height so she never sits behind the bottom HUD (rows below 0 render as sidewalk).
    private var cameraTarget: CGFloat {
        henTarget.y - size.height * 0.3
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        let dt = min(1.0 / 20, max(0, currentTime - (lastTime ?? currentTime)))
        lastTime = currentTime
        guard let viewModel else { return }

        if viewModel.isRunning {
            if viewModel.isAutopilot, let action = session.autopilotAction() {
                session.hop(action)
            }
            session.update(dt)
            let events = session.drainEvents()
            if !events.isEmpty {
                effects(for: events)
                viewModel.handle(events)
            }
            snapshotClock += dt
            if snapshotClock >= 0.1 {
                snapshotClock = 0
                viewModel.snapshot = session.snapshot
            }
        }
        sync(dt: CGFloat(dt))
    }

    // MARK: Rendering

    private func sync(dt: CGFloat) {
        // Camera.
        camY += (cameraTarget - camY) * min(1, dt * 7)
        world.position.y = -camY

        // Hen glides to her cell; long jumps (respawn) snap.
        let target = henTarget
        let distance = hypot(target.x - hen.position.x, target.y - hen.position.y)
        if distance > cell * 2.5 {
            hen.position = target
        } else {
            hen.position.x += (target.x - hen.position.x) * min(1, dt * 22)
            hen.position.y += (target.y - hen.position.y) * min(1, dt * 22)
        }
        if session.isInvulnerable {
            hen.alpha = (Int(session.time * 10) % 2 == 0) ? 0.35 : 1
        } else {
            hen.alpha = 1
        }

        let low = Int(floor(camY / cell)) - 1
        let high = Int(ceil((camY + size.height) / cell)) + 1
        for (row, node) in rowNodes where row < low || row > high {
            node.removeFromParent()
            rowNodes[row] = nil
        }
        for key in carNodes.keys where key.row < low || key.row > high {
            carNodes[key]?.removeFromParent()
            carNodes[key] = nil
        }
        for key in kernelNodes.keys where key.row < low || key.row > high {
            kernelNodes[key]?.removeFromParent()
            kernelNodes[key] = nil
        }
        for row in low...high {
            let node = rowNodes[row] ?? makeRow(row)
            updateRow(node, row: row)
            if let lane = session.lane(row) {
                syncCars(lane)
                syncKernels(lane)
            }
        }
    }

    private func texture(forRow row: Int) -> String {
        let kind = session.kind(of: row)
        if let finish = session.finishRow, row > finish { return "row_curb" }
        switch kind {
        case .curb: return "row_curb"
        case .finish: return "row_finish"
        case .island: return "row_island"
        case .lane:
            if session.lane(row)?.isHot == true { return "row_lane_hot" }
            return row % 2 == 0 ? "row_lane" : "row_lane_b"
        }
    }

    private func makeRow(_ row: Int) -> RowNode {
        let node = RowNode()
        node.position = CGPoint(x: 0, y: CGFloat(row) * cell)
        node.zPosition = 0
        node.background.texture = SKTexture(imageNamed: texture(forRow: row))
        node.background.size = CGSize(width: size.width, height: cell + 1)
        node.background.anchorPoint = .zero
        node.addChild(node.background)

        if let lane = session.lane(row) {
            let plaque = SKSpriteNode(imageNamed: lane.isHot ? "plaque_hot" : "plaque")
            plaque.size = CGSize(width: cell * 0.86, height: cell * 0.86)
            plaque.position = CGPoint(x: lane.direction > 0 ? size.width - cell * 0.5 : cell * 0.5, y: cell * 0.5)
            plaque.alpha = 0.85
            plaque.zPosition = 1
            let label = SKLabelNode(fontNamed: "AmericanTypewriter-CondensedBold")
            label.fontSize = cell * 0.26
            label.verticalAlignmentMode = .center
            label.fontColor = Self.ink
            plaque.addChild(label)
            node.addChild(plaque)
            node.plaque = plaque
            node.plaqueLabel = label

            let frozen = SKSpriteNode(color: UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1), size: CGSize(width: size.width, height: cell))
            frozen.anchorPoint = .zero
            frozen.alpha = 0
            frozen.zPosition = 2
            node.addChild(frozen)
            node.frozen = frozen

            let rush = SKSpriteNode(color: UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1), size: CGSize(width: size.width, height: cell))
            rush.anchorPoint = .zero
            rush.alpha = 0
            rush.zPosition = 2
            node.addChild(rush)
            node.rush = rush

            let honk = SKLabelNode(fontNamed: "AmericanTypewriter-CondensedBold")
            honk.text = lane.direction > 0 ? "HONK ›››" : "‹‹‹ HONK"
            honk.fontSize = cell * 0.3
            honk.fontColor = UIColor(red: 0.95, green: 0.55, blue: 0.16, alpha: 1)
            honk.verticalAlignmentMode = .center
            honk.horizontalAlignmentMode = lane.direction > 0 ? .left : .right
            honk.position = CGPoint(x: lane.direction > 0 ? 8 : size.width - 8, y: cell * 0.5)
            honk.zPosition = 30
            honk.isHidden = true
            node.addChild(honk)
            node.honk = honk

            if let sprinkler = lane.sprinkler {
                let lid = SKSpriteNode(imageNamed: "sprinkler")
                lid.size = CGSize(width: cell * 0.7, height: cell * 0.7)
                lid.position = CGPoint(x: (CGFloat(sprinkler.column) + 0.5) * cell, y: cell * 0.5)
                lid.zPosition = 3
                node.addChild(lid)
                node.lid = lid
                let spray = SKSpriteNode(imageNamed: "spray")
                spray.anchorPoint = CGPoint(x: 0.5, y: 0.1)
                spray.size = CGSize(width: cell * 0.8, height: cell * 1.2)
                spray.position = CGPoint(x: lid.position.x, y: cell * 0.35)
                spray.zPosition = 45
                spray.isHidden = true
                node.addChild(spray)
                node.spray = spray
            }
        }
        world.addChild(node)
        rowNodes[row] = node
        return node
    }

    private func updateRow(_ node: RowNode, row: Int) {
        // Fog: rows away from the hen fade into white mist.
        if fog {
            let near = abs(row - session.row) <= 1
            node.background.color = .white
            node.background.colorBlendFactor = near ? 0 : 0.6
        }
        guard let lane = session.lane(row) else { return }
        let time = session.time
        if let label = node.plaqueLabel {
            let mult = session.projectedMultiplier(row: row)
            if mult != node.lastMultiplier {
                node.lastMultiplier = mult
                label.text = mult.map { Formatters.multiplier($0) } ?? "✓"
                label.fontColor = mult == nil ? UIColor(white: 0.35, alpha: 1) : Self.ink
                node.plaque?.alpha = mult == nil ? 0.45 : 0.9
            }
        }
        node.frozen?.alpha = lane.isFrozen(at: time) ? 0.22 : 0
        node.rush?.alpha = lane.isRushing(at: time) ? 0.12 + 0.06 * CGFloat(sin(time * 12)) : 0
        if let honk = node.honk {
            honk.isHidden = !(lane.truckHonking && Int(time * 6) % 2 == 0)
        }
        if let sprinkler = lane.sprinkler, let lid = node.lid, let spray = node.spray {
            switch sprinkler.phase(at: time) {
            case .idle:
                lid.texture = SKTexture(imageNamed: "sprinkler")
                spray.isHidden = true
            case .gurgle:
                lid.texture = SKTexture(imageNamed: "sprinkler_gurgle")
                lid.alpha = 0.7 + 0.3 * CGFloat(sin(time * 14))
                spray.isHidden = true
            case .spray:
                lid.texture = SKTexture(imageNamed: "sprinkler_gurgle")
                lid.alpha = 1
                spray.isHidden = false
                spray.yScale = 0.9 + 0.15 * CGFloat(sin(time * 30))
            }
        }
    }

    private func syncCars(_ lane: LaneState) {
        var seen = Set<CarKey>()
        let rowY = (CGFloat(lane.row) + 0.5) * cell
        for car in lane.cars {
            let key = CarKey(row: lane.row, id: car.id)
            seen.insert(key)
            let node: SKSpriteNode
            if let existing = carNodes[key] {
                node = existing
            } else {
                node = SKSpriteNode(imageNamed: "car_\(car.kind.rawValue)")
                let height = car.kind == .combine || car.kind == .cornTruck ? cell * 0.78 : cell * 0.66
                node.size = CGSize(width: car.length * cell, height: height)
                node.xScale = lane.direction > 0 ? 1 : -1
                node.zPosition = 20
                if car.kind == .pickup {
                    node.color = Self.pickupTints[abs(car.id) % Self.pickupTints.count]
                    node.colorBlendFactor = 0.55
                }
                if fog {
                    let beam = SKSpriteNode(texture: Self.softDot)
                    beam.size = CGSize(width: cell * 1.3, height: cell * 0.9)
                    beam.position = CGPoint(x: car.length * cell * 0.5, y: 0)
                    beam.color = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
                    beam.colorBlendFactor = 1
                    beam.alpha = 0.9
                    beam.zPosition = 1
                    beam.name = "beam"
                    node.addChild(beam)
                }
                world.addChild(node)
                carNodes[key] = node
            }
            node.position = CGPoint(x: (CGFloat(car.x) + CGFloat(car.length) / 2) * cell, y: rowY)
            if fog {
                let far = abs(lane.row - session.row) > 1
                node.color = .white
                node.colorBlendFactor = far ? 0.8 : (car.kind == .pickup ? 0.3 : 0)
            }
        }
        for key in carNodes.keys where key.row == lane.row && !seen.contains(key) {
            carNodes[key]?.removeFromParent()
            carNodes[key] = nil
        }
    }

    private func syncKernels(_ lane: LaneState) {
        var seen = Set<CarKey>()
        for kernel in lane.kernels {
            let key = CarKey(row: lane.row, id: kernel.id)
            seen.insert(key)
            if kernelNodes[key] == nil {
                let node = SKSpriteNode(imageNamed: "kernel")
                node.size = CGSize(width: cell * 0.62, height: cell * 0.62)
                node.position = center(row: lane.row, column: kernel.column)
                node.zPosition = 10
                node.setScale(0.1)
                node.run(.sequence([.scale(to: 1, duration: 0.2),
                                    .repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.4), .moveBy(x: 0, y: -4, duration: 0.4)]))]))
                world.addChild(node)
                kernelNodes[key] = node
            }
            // Blink in the last 2 seconds.
            let remaining = kernel.expires - session.time
            kernelNodes[key]?.alpha = remaining < 2 && Int(remaining * 8) % 2 == 0 ? 0.3 : 1
        }
        for key in kernelNodes.keys where key.row == lane.row && !seen.contains(key) {
            kernelNodes[key]?.removeFromParent()
            kernelNodes[key] = nil
        }
    }

    // MARK: Effects

    private func effects(for events: [RunEvent]) {
        for event in events {
            switch event {
            case .hop(_, let column, _):
                if column != lastColumn { henFacingLeft = column < lastColumn }
                lastColumn = column
                hen.xScale = henFacingLeft ? -1 : 1
                hen.run(.sequence([.scaleY(to: 1.15, duration: 0.05), .scaleY(to: 1, duration: 0.08)]))
            case .laneScored(let row, let points, let mult):
                floatText("+\(points)  \(Formatters.multiplier(mult))", at: CGPoint(x: hen.position.x, y: (CGFloat(row) + 1) * cell),
                          color: UIColor(red: 1, green: 0.84, blue: 0.29, alpha: 1), size: cell * 0.28)
            case .roosted(let amount):
                floatText("+\(amount) BANKED", at: CGPoint(x: hen.position.x, y: hen.position.y + cell), color: .white, size: cell * 0.36)
                for i in 0..<6 {
                    let egg = SKSpriteNode(imageNamed: "egg")
                    egg.size = CGSize(width: cell * 0.3, height: cell * 0.3)
                    egg.position = hen.position
                    egg.zPosition = 80
                    world.addChild(egg)
                    let dx = CGFloat(i - 3) * cell * 0.25
                    egg.run(.sequence([.group([.moveBy(x: dx, y: cell * 1.6, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
                }
            case .kernel(let row, let column):
                burst(at: center(row: row, column: column), color: UIColor(red: 1, green: 0.84, blue: 0.29, alpha: 1), count: 8)
            case .bell:
                let ring = SKShapeNode(circleOfRadius: cell * 0.5)
                ring.strokeColor = UIColor(red: 0.18, green: 0.9, blue: 0.84, alpha: 1)
                ring.lineWidth = 6
                ring.glowWidth = 6
                ring.position = hen.position
                ring.zPosition = 90
                world.addChild(ring)
                ring.run(.sequence([.group([.scale(to: 6, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
            case .honk:
                break
            case .hit(let cause, _):
                burst(at: hen.position, color: cause == .spray ? .orange : .white, count: 14, feathers: true)
                flash.color = cause == .spray ? .orange : .red
                flash.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.05), .fadeOut(withDuration: 0.35)]))
                world.run(.sequence([.moveBy(x: 10, y: 0, duration: 0.04), .moveBy(x: -20, y: 0, duration: 0.06), .moveBy(x: 10, y: 0, duration: 0.04)]))
            case .finished:
                for i in 0..<20 {
                    let p = CGPoint(x: CGFloat(i % 5) * cell + cell * 0.5, y: hen.position.y)
                    burst(at: p, color: UIColor(red: 1, green: 0.37, blue: 0.82, alpha: 1), count: 3)
                }
            case .outOfFeathers:
                hen.run(.sequence([.rotate(byAngle: .pi * 2, duration: 0.5), .fadeAlpha(to: 0.4, duration: 0.2)]))
            }
        }
    }

    private func floatText(_ text: String, at point: CGPoint, color: UIColor, size: CGFloat) {
        let label = SKLabelNode(fontNamed: "AmericanTypewriter-CondensedBold")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.position = point
        label.zPosition = 100
        world.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: cell * 0.8, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }

    private func burst(at point: CGPoint, color: UIColor, count: Int, feathers: Bool = false) {
        for i in 0..<count {
            let node: SKSpriteNode
            if feathers {
                node = SKSpriteNode(imageNamed: "feather")
                node.size = CGSize(width: cell * 0.3, height: cell * 0.3)
            } else {
                node = SKSpriteNode(texture: Self.softDot)
                node.size = CGSize(width: cell * 0.25, height: cell * 0.25)
                node.color = color
                node.colorBlendFactor = 1
            }
            node.position = point
            node.zPosition = 95
            world.addChild(node)
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let distance = cell * (feathers ? 0.9 : 0.6)
            node.run(.sequence([
                .group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.5),
                        .rotate(byAngle: feathers ? 2 : 0, duration: 0.5),
                        .fadeOut(withDuration: 0.5)]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: Touches: tap = hop forward, swipe = sidestep / hop back

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = touches.first?.location(in: view)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = touchStart, let end = touches.first?.location(in: view) else { return }
        touchStart = nil
        let dx = end.x - start.x
        let dy = end.y - start.y
        let action: PilotAction
        if hypot(dx, dy) < 24 {
            action = .forward
        } else if abs(dx) > abs(dy) {
            action = dx > 0 ? .right : .left
        } else {
            // UIKit y grows downward.
            action = dy > 0 ? .back : .forward
        }
        viewModel?.input(action)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }
}
