import SwiftUI

struct ContentView: View {
    @StateObject private var model = RealityViewModel()

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.039, blue: 0.047).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("MONDAYID REALITY · LOCAL AUTHORITY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.2)
                        .foregroundStyle(.secondary)

                    Text(model.headline)
                        .font(.system(size: 42, weight: .semibold, design: .default))
                        .tracking(-1.7)
                        .foregroundStyle(model.accent)
                        .padding(.top, 46)

                    if let tick = model.tick {
                        Text(tick.reality.reason)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .padding(.top, 14)

                        HStack(spacing: 8) {
                            context("Home", "Nahariya")
                            context("Work", "Haifa")
                        }.padding(.top, 26)
                        HStack(spacing: 8) {
                            context("Family", "Nahariya")
                            context("Route", "Nahariya → Haifa")
                        }.padding(.top, 8)

                        VStack(spacing: 0) {
                            row("Official-origin receptor", tick.official.coverage.rawValue)
                            row("Lifecycle", tick.lifecycle)
                            row("Authority", tick.reality.state.rawValue)
                        }
                        .padding(.top, 30)

                        if tick.reality.state == .officialActive {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("CURRENT OFFICIAL INSTRUCTION")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.6)
                                    .foregroundStyle(.red)
                                ForEach(tick.reality.relevantAlerts, id: \.self) { alert in
                                    Text(alert.instruction.isEmpty ? alert.title : alert.instruction)
                                        .font(.system(size: 20, weight: .semibold))
                                }
                            }
                            .padding(20)
                            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
                            .padding(.top, 24)
                        }
                    }

                    Text("This app describes official-origin observations for saved contexts. It does not infer a person's physical condition. Keep current Home Front Command alerts and instructions enabled.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary.opacity(0.72))
                        .padding(.top, 34)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .refreshable { await model.refresh() }
        }
        .task { model.start() }
        .onDisappear { model.stop() }
    }

    private func context(_ name: String, _ area: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.system(size: 12, weight: .semibold))
            Text(area).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).font(.system(size: 14))
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 15)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }
}
