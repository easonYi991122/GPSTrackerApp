//
//  DataModels.swift
//  GPSTrackerApp
// 核心功能：
// 1. 定义SwiftData的Track和LocationPoint模型
// 2. 建立模型间的关系
// 3. 提供数据验证和计算属性
// 4. 定义数据传输对象
//
//  Created by Shuhan Yi on 2025/8/7.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Track {
    @Attribute(.unique) var id: UUID
    var name: String
    var startTime: Date
    var endTime: Date?
    @Relationship(deleteRule: .cascade) var locations: [LocationPoint] = []
    
    init(startTime: Date) {
        self.id = UUID()
        self.name = "轨迹 - \(startTime.formatted(date: .abbreviated, time: .shortened))"
        self.startTime = startTime
    }
    
    // 计算属性
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isCompleted: Bool {
        return endTime != nil
    }
}

@Model
final class LocationPoint {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var speed: Double // 米/秒
    var altitude: Double // 米
    var horizontalAccuracy: Double // 米
    var track: Track?
    
    init(latitude: Double, longitude: Double, timestamp: Date, speed: Double, altitude: Double, horizontalAccuracy: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
    }
    
    // 计算属性
    var speedInKmh: Double {
        return speed * 3.6
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// 关联关系：
// ← GPSTrackerApp.swift (被注册到ModelContainer)
// ↔ MainView.swift (创建和保存Track)
// ↔ HistoryView.swift (查询Track列表)
// ↔ TrackDetailView.swift (显示Track详情)
// ← LocationManager.swift (提供数据创建LocationPoint)
