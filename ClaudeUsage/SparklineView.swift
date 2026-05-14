import SwiftUI

struct SparklineView: View {
    let history: [HistoryPoint]
    var useSevenDay: Bool = false

    private var values: [Double] {
        history.map { Double(useSevenDay ? $0.s7dPct : $0.s5hPct) }
    }

    private var latestPct: Int {
        useSevenDay ? (history.last?.s7dPct ?? 0) : (history.last?.s5hPct ?? 0)
    }

    var body: some View {
        if values.count < 2 {
            Text("Not enough data yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 40)
        } else {
            Canvas { context, size in
                let color = usageColor(latestPct)
                let w = size.width
                let h = size.height

                func xFor(_ i: Int) -> CGFloat {
                    CGFloat(i) / CGFloat(values.count - 1) * w
                }
                func yFor(_ v: Double) -> CGFloat {
                    CGFloat(1 - v / 100) * h
                }

                var linePath = Path()
                linePath.move(to: CGPoint(x: xFor(0), y: yFor(values[0])))
                for i in 1..<values.count {
                    linePath.addLine(to: CGPoint(x: xFor(i), y: yFor(values[i])))
                }

                var fillPath = linePath
                fillPath.addLine(to: CGPoint(x: xFor(values.count - 1), y: h))
                fillPath.addLine(to: CGPoint(x: xFor(0), y: h))
                fillPath.closeSubpath()

                context.fill(fillPath, with: .color(color.opacity(0.2)))
                context.stroke(linePath, with: .color(color), lineWidth: 1.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
        }
    }
}
