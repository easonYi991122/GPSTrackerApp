//
//  TrackUtils.swift
//  GPSTrackerApp
// 核心功能：
// 1. 轨迹距离计算
// 2. 速度和时间统计
// 3. 海拔变化分析
// 4. 数据导出功能
// 5. 时间格式化工具
//
//  Created by Shuhan Yi on 2025/8/7.
//

// 实现思路：
import Foundation
import CoreLocation
import SwiftUI
import UIKit

struct TrackUtils {
    
    // MARK: - 距离计算（增强版本）
    static func calculateDistance(for track: Track) -> Double? {
        guard track.locations.count > 1 else { return nil }
        
        var totalDistance: Double = 0
        var validSegments = 0
        
        // 按时间戳排序确保顺序正确
        let sortedLocations = track.locations.sorted { $0.timestamp < $1.timestamp }
        
        for i in 1..<sortedLocations.count {
            let previousLocation = CLLocation(
                latitude: sortedLocations[i-1].latitude,
                longitude: sortedLocations[i-1].longitude
            )
            let currentLocation = CLLocation(
                latitude: sortedLocations[i].latitude,
                longitude: sortedLocations[i].longitude
            )
            
            let segmentDistance = currentLocation.distance(from: previousLocation)
            let timeInterval = sortedLocations[i].timestamp.timeIntervalSince(sortedLocations[i-1].timestamp)
            
            // 数据验证：跳过异常的距离段
            if segmentDistance <= 1000 && timeInterval > 0 { // 最大1km的单段距离
                let segmentSpeed = (segmentDistance / timeInterval) * 3.6 // km/h
                
                // 跳过速度异常的段（超过150km/h）
                if segmentSpeed <= 150 {
                    totalDistance += segmentDistance
                    validSegments += 1
                } else {
                    print("跳过异常速度段: \(segmentSpeed) km/h, 距离: \(segmentDistance) m")
                }
            } else {
                print("跳过异常距离段: \(segmentDistance) m, 时间间隔: \(timeInterval) s")
            }
        }
        
        print("距离计算完成: 总距离 \(totalDistance/1000.0) km, 有效段数 \(validSegments)/\(sortedLocations.count-1)")
        
        return totalDistance / 1000.0 // 转换为公里
    }
    
    // MARK: - 速度计算（增强版本）
    static func calculateAverageSpeed(for track: Track) -> Double? {
        guard let distance = calculateDistance(for: track),
              let duration = track.duration,
              duration > 0,
              distance > 0 else { return nil }
        
        let avgSpeed = (distance / duration) * 3600 // km/h
        
        // 合理性检查
        if avgSpeed > 100 {
            print("警告：计算出的平均速度异常: \(avgSpeed) km/h")
            return nil
        }
        
        return avgSpeed
    }
    
    static func calculateMaxSpeed(for track: Track) -> Double? {
        guard !track.locations.isEmpty else { return nil }
        
        let maxSpeed = track.locations.compactMap { location -> Double? in
            let speed = location.speedInKmh
            // 过滤异常速度
            return speed <= 150 ? speed : nil
        }.max()
        
        return maxSpeed
    }
    
    // 新增：计算移动平均速度（更准确）
    static func calculateMovingAverageSpeed(for track: Track, windowSize: Int = 5) -> [Double] {
        guard track.locations.count > windowSize else { return [] }
        
        let sortedLocations = track.locations.sorted { $0.timestamp < $1.timestamp }
        var speeds: [Double] = []
        
        for i in windowSize..<sortedLocations.count {
            let windowLocations = Array(sortedLocations[(i-windowSize)...i])
            
            var windowDistance: Double = 0
            var windowTime: TimeInterval = 0
            
            for j in 1..<windowLocations.count {
                let prevLoc = CLLocation(
                    latitude: windowLocations[j-1].latitude,
                    longitude: windowLocations[j-1].longitude
                )
                let currLoc = CLLocation(
                    latitude: windowLocations[j].latitude,
                    longitude: windowLocations[j].longitude
                )
                
                windowDistance += currLoc.distance(from: prevLoc)
                windowTime += windowLocations[j].timestamp.timeIntervalSince(windowLocations[j-1].timestamp)
            }
            
            if windowTime > 0 {
                let avgSpeed = (windowDistance / windowTime) * 3.6 // km/h
                if avgSpeed <= 150 { // 过滤异常值
                    speeds.append(avgSpeed)
                }
            }
        }
        
        return speeds
    }
    
    // MARK: - 海拔计算（增强版本）
    static func calculateMaxAltitude(for track: Track) -> Double? {
        guard !track.locations.isEmpty else { return nil }
        
        let validAltitudes = track.locations.compactMap { location -> Double? in
            // 过滤明显异常的海拔值
            let altitude = location.altitude
            return (altitude >= -500 && altitude <= 10000) ? altitude : nil
        }
        
        return validAltitudes.max()
    }
    
    static func calculateMinAltitude(for track: Track) -> Double? {
        guard !track.locations.isEmpty else { return nil }
        
        let validAltitudes = track.locations.compactMap { location -> Double? in
            let altitude = location.altitude
            return (altitude >= -500 && altitude <= 10000) ? altitude : nil
        }
        
        return validAltitudes.min()
    }
    
    static func calculateElevationGain(for track: Track) -> Double? {
        guard track.locations.count > 1 else { return nil }
        
        let sortedLocations = track.locations.sorted { $0.timestamp < $1.timestamp }
        var totalGain: Double = 0
        
        for i in 1..<sortedLocations.count {
            let elevationChange = sortedLocations[i].altitude - sortedLocations[i-1].altitude
            
            // 只计算合理的海拔变化（小于100米的单次变化）
            if elevationChange > 0 && elevationChange <= 100 {
                totalGain += elevationChange
            }
        }
        
        return totalGain
    }
    
    // MARK: - 时间格式化
    static func formatDuration(for track: Track) -> String {
        guard let duration = track.duration else { return "未完成" }
        return formatTimeInterval(duration)
    }
    
    static func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - 数据导出（增强版本）
    static func exportToGPX(track: Track) -> String {
        let sortedLocations = track.locations.sorted { $0.timestamp < $1.timestamp }
        
        var gpxString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GPSTracker" xmlns="http://www.topografix.com/GPX/1/1">
        <metadata>
        <name>\(track.name)</name>
        <time>\(ISO8601DateFormatter().string(from: track.startTime))</time>
        </metadata>
        <trk>
        <name>\(track.name)</name>
        <trkseg>
        """
        
        for location in sortedLocations {
            // 数据验证
            guard location.horizontalAccuracy <= 50,
                  location.altitude >= -500 && location.altitude <= 10000 else {
                continue
            }
            
            gpxString += """
            <trkpt lat="\(location.latitude)" lon="\(location.longitude)">
            <ele>\(String(format: "%.1f", location.altitude))</ele>
            <time>\(ISO8601DateFormatter().string(from: location.timestamp))</time>
            """
            
            if location.speed >= 0 {
                gpxString += "<speed>\(String(format: "%.2f", max(0, location.speed)))</speed>"
            }
            
            gpxString += "</trkpt>\n"
        }
        
        gpxString += """
        </trkseg>
        </trk>
        </gpx>
        """
        
        return gpxString
    }
    
    static func exportToCSV(track: Track) -> String {
        let sortedLocations = track.locations.sorted { $0.timestamp < $1.timestamp }
        
        var csvString = "Timestamp,Latitude,Longitude,Altitude(m),Speed(m/s),Speed(km/h),Accuracy(m)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for location in sortedLocations {
            // 数据验证
            guard location.horizontalAccuracy <= 50 else { continue }
            
            let speedKmh = max(0, location.speed * 3.6)
            csvString += "\(dateFormatter.string(from: location.timestamp)),\(location.latitude),\(location.longitude),\(String(format: "%.1f", location.altitude)),\(String(format: "%.2f", max(0, location.speed))),\(String(format: "%.2f", speedKmh)),\(String(format: "%.1f", location.horizontalAccuracy))\n"
        }
        
        return csvString
    }
    
    // MARK: - 数据过滤和平滑（增强版本）
    static func filterInaccuratePoints(locations: [LocationPoint], accuracyThreshold: Double = 30.0) -> [LocationPoint] {
        return locations.filter { location in
            location.horizontalAccuracy > 0 &&
            location.horizontalAccuracy <= accuracyThreshold &&
            location.altitude >= -500 &&
            location.altitude <= 10000
        }
    }
    
    static func smoothTrack(locations: [LocationPoint], windowSize: Int = 3) -> [LocationPoint] {
        guard locations.count > windowSize else { return locations }
        
        let sortedLocations = locations.sorted { $0.timestamp < $1.timestamp }
        var smoothedLocations: [LocationPoint] = []
        
        for i in 0..<sortedLocations.count {
            let startIndex = max(0, i - windowSize/2)
            let endIndex = min(sortedLocations.count - 1, i + windowSize/2)
            
            let window = Array(sortedLocations[startIndex...endIndex])
            let avgLat = window.map { $0.latitude }.reduce(0, +) / Double(window.count)
            let avgLon = window.map { $0.longitude }.reduce(0, +) / Double(window.count)
            let avgAlt = window.map { $0.altitude }.reduce(0, +) / Double(window.count)
            
            let smoothedPoint = LocationPoint(
                latitude: avgLat,
                longitude: avgLon,
                timestamp: sortedLocations[i].timestamp,
                speed: sortedLocations[i].speed,
                altitude: avgAlt,
                horizontalAccuracy: sortedLocations[i].horizontalAccuracy
            )
            
            smoothedLocations.append(smoothedPoint)
        }
        
        return smoothedLocations
    }
    
    // 新增：轨迹数据完整性验证
    static func validateTrackData(track: Track) -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []
        
        // 检查基本数据
        if track.locations.isEmpty {
            issues.append("轨迹没有位置数据")
            return (false, issues)
        }
        
        if track.locations.count < 2 {
            issues.append("轨迹数据点太少（少于2个）")
        }
        
        // 检查时间顺序
        let sortedByTime = track.locations.sorted { $0.timestamp < $1.timestamp }
        if sortedByTime != track.locations {
            issues.append("位置数据时间顺序不正确")
        }
        
        // 检查精度
        let poorAccuracyCount = track.locations.filter { $0.horizontalAccuracy > 50 }.count
        if poorAccuracyCount > track.locations.count / 2 {
            issues.append("超过一半的数据点精度较差（>50m）")
        }
        
        // 检查速度异常
        let highSpeedCount = track.locations.filter { $0.speedInKmh > 150 }.count
        if highSpeedCount > 0 {
            issues.append("存在\(highSpeedCount)个异常高速数据点（>150km/h）")
        }
        
        // 检查距离跳跃
        var largeJumps = 0
        for i in 1..<sortedByTime.count {
            let prevLoc = CLLocation(latitude: sortedByTime[i-1].latitude, longitude: sortedByTime[i-1].longitude)
            let currLoc = CLLocation(latitude: sortedByTime[i].latitude, longitude: sortedByTime[i].longitude)
            let distance = currLoc.distance(from: prevLoc)
            
            if distance > 1000 { // 超过1km的跳跃
                largeJumps += 1
            }
        }
        
        if largeJumps > 0 {
            issues.append("存在\(largeJumps)个大距离跳跃（>1km）")
        }
        
        // 检查总体合理性
        if let avgSpeed = calculateAverageSpeed(for: track), avgSpeed > 100 {
            issues.append("平均速度异常高：\(String(format: "%.1f", avgSpeed)) km/h")
        }
        
        return (issues.isEmpty, issues)
    }
}

// 导出视图组件（增强版本）
struct ExportView: View {
    let track: Track
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isValidating = false
    @State private var validationResults: (isValid: Bool, issues: [String])?
    
    var body: some View {
        NavigationView {
            List {
                // 数据验证部分
                Section("数据验证") {
                    if let results = validationResults {
                        if results.isValid {
                            Label("数据验证通过", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("发现数据问题", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            ForEach(results.issues, id: \.self) { issue in
                                Text("• \(issue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Button("验证轨迹数据") {
                            validateData()
                        }
                        .disabled(isValidating)
                    }
                }
                
                // 导出选项
                Section("导出选项") {
                    Button("导出为GPX") {
                        exportGPX()
                    }
                    
                    Button("导出为CSV") {
                        exportCSV()
                    }
                    
                    Button("保存到文件") {
                        saveToDocuments()
                    }
                }
                
                // 统计信息
                Section("轨迹统计") {
                    HStack {
                        Text("数据点数量")
                        Spacer()
                        Text("\(track.locations.count)")
                    }
                    
                    if let distance = TrackUtils.calculateDistance(for: track) {
                        HStack {
                            Text("总距离")
                            Spacer()
                            Text("\(distance, specifier: "%.2f") km")
                        }
                    }
                    
                    if let duration = track.duration {
                        HStack {
                            Text("总时长")
                            Spacer()
                            Text(TrackUtils.formatTimeInterval(duration))
                        }
                    }
                }
            }
            .navigationTitle("导出轨迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("导出结果", isPresented: $showingAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                validateData()
            }
        }
    }
    
    private func validateData() {
        isValidating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let results = TrackUtils.validateTrackData(track: track)
            DispatchQueue.main.async {
                self.validationResults = results
                self.isValidating = false
            }
        }
    }
    
    private func exportGPX() {
        let gpxContent = TrackUtils.exportToGPX(track: track)
        shareContent(gpxContent, fileName: "\(track.name).gpx")
    }
    
    private func exportCSV() {
        let csvContent = TrackUtils.exportToCSV(track: track)
        shareContent(csvContent, fileName: "\(track.name).csv")
    }
    
    private func saveToDocuments() {
        let gpxContent = TrackUtils.exportToGPX(track: track)
        let csvContent = TrackUtils.exportToCSV(track: track)
        
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            alertMessage = "无法访问文档目录"
            showingAlert = true
            return
        }
        
        do {
            let gpxURL = documentsURL.appendingPathComponent("\(track.name).gpx")
            let csvURL = documentsURL.appendingPathComponent("\(track.name).csv")
            
            try gpxContent.write(to: gpxURL, atomically: true, encoding: .utf8)
            try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            
            alertMessage = "文件已保存到应用文档目录\n可通过iTunes文件共享或Files应用访问"
            showingAlert = true
        } catch {
            alertMessage = "保存失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func shareContent(_ content: String, fileName: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            
            let activityViewController = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    if let popover = activityViewController.popoverPresentationController {
                        popover.sourceView = rootViewController.view
                        popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                   y: rootViewController.view.bounds.midY,
                                                   width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    rootViewController.present(activityViewController, animated: true)
                }
            }
        } catch {
            print("Failed to write file: \(error)")
            alertMessage = "导出失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// 关联关系：
// → MainView.swift (提供实时计算功能)
// → HistoryView.swift (提供列表显示的统计信息)
// → TrackDetailView.swift (提供详情页面的所有统计计算)
// ← LocationManager.swift (使用时间格式化功能)
// ↔ DataModels.swift (操作Track和LocationPoint数据)
