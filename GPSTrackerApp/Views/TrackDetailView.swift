//
//  TrackDetailView.swift
//  GPSTrackerApp
// 核心功能：
// 1. 完整轨迹在地图上的可视化展示
// 2. 详细统计信息面板（总里程、时长、速度等）
// 3. 轨迹数据导出功能
// 4. 轨迹重命名和删除功能
//
//  Created by Shuhan Yi on 2025/8/7.

import SwiftUI
import MapKit

struct TrackDetailView: View {
    let track: Track
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportSheet = false
    @State private var showingRenameAlert = false
    @State private var newTrackName = ""
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // 计算属性：按时间排序的位置点
    private var sortedLocations: [LocationPoint] {
        track.locations.sorted { $0.timestamp < $1.timestamp }
    }
    
    // 计算属性：排序后的坐标数组
    private var sortedCoordinates: [CLLocationCoordinate2D] {
        sortedLocations.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude).forMapDisplay
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 轨迹地图展示 - 修复后的版本
                Map(position: $cameraPosition) {
                    // 使用排序后的坐标绘制轨迹
                    if !sortedCoordinates.isEmpty {
                        MapPolyline(coordinates: sortedCoordinates)
                            .stroke(.blue, lineWidth: 3)
                        
                        // 起点标记（使用排序后的第一个点）
                        if let firstLocation = sortedLocations.first {
                            Annotation("起点", coordinate: CLLocationCoordinate2D(
                                latitude: firstLocation.latitude,
                                longitude: firstLocation.longitude
                            ).forMapDisplay) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 20, height: 20)
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 16, height: 16)
                                    Text("起")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // 终点标记（使用排序后的最后一个点）
                        if let lastLocation = sortedLocations.last,
                           sortedLocations.count > 1 { // 确保起点和终点不是同一个点
                            Annotation("终点", coordinate: CLLocationCoordinate2D(
                                latitude: lastLocation.latitude,
                                longitude: lastLocation.longitude
                            ).forMapDisplay) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 20, height: 20)
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 16, height: 16)
                                    Text("终")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // 可选：添加方向箭头（每隔一定距离显示一个）
                        ForEach(Array(stride(from: 0, to: sortedLocations.count - 1, by: max(1, sortedLocations.count / 10))), id: \.self) { index in
                            if index + 1 < sortedLocations.count {
                                let currentLocation = sortedLocations[index]
                                let nextLocation = sortedLocations[index + 1]
                                let bearing = calculateBearing(
                                    from: currentLocation,
                                    to: nextLocation
                                )
                                
                                Annotation("", coordinate: CLLocationCoordinate2D(
                                    latitude: currentLocation.latitude,
                                    longitude: currentLocation.longitude
                                ).forMapDisplay) {
                                    Image(systemName: "arrowtriangle.up.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .rotationEffect(.degrees(bearing))
                                }
                            }
                        }
                    }
                }
                .frame(height: 300)
                .cornerRadius(12)
                .onAppear {
                    // 设置地图初始视图以包含整个轨迹
                    if !sortedCoordinates.isEmpty {
                        let region = calculateMapRegion(coordinates: sortedCoordinates)
                        cameraPosition = .region(region)
                    }
                }
                
                // 轨迹信息摘要
                if !sortedLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("轨迹信息")
                                .font(.headline)
                            Spacer()
                            Text("数据点: \(sortedLocations.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("开始时间: \(formatDate(track.startTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let endTime = track.endTime {
                                Text("结束时间: \(formatDate(endTime))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                
                // 统计信息面板
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCardView(title: "总距离", value: String(format: "%.2f km", TrackUtils.calculateDistance(for: track) ?? 0))
                    StatCardView(title: "总时长", value: TrackUtils.formatDuration(for: track))
                    StatCardView(title: "平均速度", value: String(format: "%.1f km/h", TrackUtils.calculateAverageSpeed(for: track) ?? 0))
                    StatCardView(title: "最高速度", value: String(format: "%.1f km/h", TrackUtils.calculateMaxSpeed(for: track) ?? 0))
                    StatCardView(title: "最高海拔", value: String(format: "%.0f m", TrackUtils.calculateMaxAltitude(for: track) ?? 0))
                    StatCardView(title: "海拔爬升", value: String(format: "%.0f m", TrackUtils.calculateElevationGain(for: track) ?? 0))
                }
                
                // 操作按钮
                VStack(spacing: 12) {
                    Button("导出轨迹") {
                        showingExportSheet = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("重命名") {
                        newTrackName = track.name
                        showingRenameAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("删除轨迹") {
                        deleteTrack()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            ExportView(track: track)
        }
        .alert("重命名轨迹", isPresented: $showingRenameAlert) {
            TextField("轨迹名称", text: $newTrackName)
            Button("确定") {
                track.name = newTrackName
                try? modelContext.save()
            }
            Button("取消", role: .cancel) { }
        }
    }
    
    // 计算地图区域以包含所有轨迹点
    private func calculateMapRegion(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let latDelta = max(maxLat - minLat, 0.001) * 1.2 // 添加20%边距
        let lonDelta = max(maxLon - minLon, 0.001) * 1.2
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
    
    // 计算两点之间的方位角（用于方向箭头）
    private func calculateBearing(from: LocationPoint, to: LocationPoint) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(x, y) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func deleteTrack() {
        modelContext.delete(track)
        try? modelContext.save()
        dismiss()
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

#Preview {
    let track = createSampleTrackForPreview()
    
    return NavigationView {
        TrackDetailView(track: track)
    }
    .modelContainer(for: [Track.self, LocationPoint.self], inMemory: true)
}

private func createSampleTrackForPreview() -> Track {
    let track = Track(startTime: Date().addingTimeInterval(-3600))
    track.name = "预览轨迹"
    track.endTime = Date()
    
    // 创建一个简单的轨迹路径
    let baseLatitude = 39.9042
    let baseLongitude = 116.4074
    let coordinates = [
        (baseLatitude, baseLongitude),
        (baseLatitude + 0.01, baseLongitude),
        (baseLatitude + 0.01, baseLongitude + 0.01),
        (baseLatitude, baseLongitude + 0.01),
        (baseLatitude, baseLongitude)
    ]
    
    for (index, coordinate) in coordinates.enumerated() {
        let location = LocationPoint(
            latitude: coordinate.0,
            longitude: coordinate.1,
            timestamp: track.startTime.addingTimeInterval(Double(index) * 720),
            speed: Double.random(in: 8...12),
            altitude: 50 + Double.random(in: -10...10)
        )
        location.track = track
        track.locations.append(location)
    }
    
    return track
}

// 关联关系：
// ← HistoryView.swift (接收Track对象)
// ↔ DataModels.swift (修改和删除Track)
// → TrackUtils.swift (计算所有统计信息)
