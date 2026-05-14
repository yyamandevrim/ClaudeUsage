import SwiftUI

struct SparklineView: View {
    let history: [HistoryPoint]

    var body: some View {
        if history.count < 2 {
            Text("Not enough data yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 40)
        } else {
            Canvas { context, size in
                let values = history.map { Double($0.s5hPct) }
                let latest = history.last!.s5hPct
                let color = usageColor(latest)

                let maxY = 100.0
                let minY = 0.0
                let w = size.width
                let h = size.height

                func xFor(_ i: Int) -> CGFloat {
                    CGFloat(i) / CGFloat(values.count - 1) * w
                }
                func yFor(_ v: Double) -> CGFloat {
                    CGFloat(1 - (v - minY) / (maxY - minY)) * h
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
