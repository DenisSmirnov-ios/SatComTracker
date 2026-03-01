import SwiftUI

struct ActiveCompassView: View {
    let satelliteAzimuth: Double
    @ObservedObject var compassManager: CompassManager
    
    var relativeAzimuth: Double {
        let diff = satelliteAzimuth - compassManager.heading
        return (diff.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 200, height: 200)
            
            Text("N")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.red)
                .offset(y: -90)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("S")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)
                .offset(y: 90)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("W")
                .font(.system(size: 20, weight: .bold))
                .offset(x: -90)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("E")
                .font(.system(size: 20, weight: .bold))
                .offset(x: 90)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Triangle()
                .fill(Color.red)
                .frame(width: 24, height: 36)
                .offset(y: -85)
                .rotationEffect(.degrees(relativeAzimuth))
            
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 20, height: 20)
            
            if compassManager.isCalibrating {
                Text("⚠️")
                    .font(.caption)
                    .offset(y: 70)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SatelliteDetailView: View {
    let satellite: Satellite
    @ObservedObject var compassManager: CompassManager
    @ObservedObject var frequencyStore = FrequencyStore.shared
    @State private var showFrequencyEdit = false
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .none
        return f
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HeaderView(satellite: satellite)
                UpdateTimeView(timestamp: satellite.timestamp, timeFormatter: timeFormatter)
                
                if !satellite.isVisible {
                    BelowHorizonWarning(elevation: satellite.elevation)
                }
                
                if satellite.isVisible {
                    CompassSection(satellite: satellite, compassManager: compassManager)
                }
                
                FrequencySection(
                    satelliteId: satellite.id,
                    satelliteName: satellite.name,
                    onEdit: { showFrequencyEdit = true }
                )
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showFrequencyEdit = true }) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .overlay(
                            Group {
                                let channels = frequencyStore.getPredefinedChannels(for: satellite.id)
                                if !channels.isEmpty {
                                    Text("\(channels.count)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -10)
                                }
                            }
                        )
                }
            }
        }
        .sheet(isPresented: $showFrequencyEdit) {
            FrequencyEditView(satelliteId: satellite.id, satelliteName: satellite.name)
        }
        .onAppear {
            compassManager.start()
        }
        .onDisappear {
            compassManager.stop()
        }
    }
}

struct HeaderView: View {
    let satellite: Satellite
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: satellite.isVisible ? "circle.fill" : "circle")
                    .font(.system(size: 10))
                    .foregroundColor(satellite.isVisible ? .green : .red)
                
                Text(satellite.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Text("NORAD: \(satellite.id)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.top, 8)
    }
}

struct UpdateTimeView: View {
    let timestamp: Date
    let timeFormatter: DateFormatter
    
    var body: some View {
        HStack {
            Spacer()
            Label(timeFormatter.string(from: timestamp), systemImage: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

struct BelowHorizonWarning: View {
    let elevation: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(.red)
                Text("Спутник ниже горизонта")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            Text(String(format: "Элевация: %.1f° ниже горизонта", abs(elevation)))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(16)
    }
}

struct CompassSection: View {
    let satellite: Satellite
    @ObservedObject var compassManager: CompassManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Наведение на спутник", systemImage: "scope")
                    .font(.headline)
                Spacer()
                if compassManager.isCalibrating {
                    Label("Калибровка", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            ActiveCompassView(satelliteAzimuth: satellite.azimuth, compassManager: compassManager)
                .frame(height: 220)
            
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("АЗИМУТ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f°", satellite.azimuth))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("ЭЛЕВАЦИЯ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f°", satellite.elevation))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 10) {
                InstructionRow(number: 1, text: "Встаньте лицом на север")
                InstructionRow(number: 2, text: String(format: "Повернитесь на %.0f° вправо", satellite.azimuth))
                InstructionRow(number: 3, text: String(format: "Поднимите взгляд на %.0f°", satellite.elevation))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}
