//
//  CoordinateConverter.swift
//  GPSTrackerApp
//
//  坐标系转换工具
//  处理WGS84、GCJ-02、BD-09之间的转换
//

import Foundation
import CoreLocation

struct CoordinateConverter {
    
    // 常量定义
    private static let pi = 3.1415926535897932384626
    private static let a = 6378245.0  // 长半轴
    private static let ee = 0.00669342162296594323  // 偏心率平方
    
    // MARK: - WGS84转GCJ-02 (GPS坐标转火星坐标)
    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        if outOfChina(latitude: latitude, longitude: longitude) {
            return (latitude: latitude, longitude: longitude)
        }
        
        var dLat = transformLat(longitude - 105.0, latitude - 35.0)
        var dLon = transformLon(longitude - 105.0, latitude - 35.0)
        
        let radLat = latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        
        let mgLat = latitude + dLat
        let mgLon = longitude + dLon
        
        return (latitude: mgLat, longitude: mgLon)
    }
    
    // MARK: - GCJ-02转WGS84 (火星坐标转GPS坐标)
    static func gcj02ToWgs84(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        if outOfChina(latitude: latitude, longitude: longitude) {
            return (latitude: latitude, longitude: longitude)
        }
        
        var dLat = transformLat(longitude - 105.0, latitude - 35.0)
        var dLon = transformLon(longitude - 105.0, latitude - 35.0)
        
        let radLat = latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        
        let mgLat = latitude - dLat
        let mgLon = longitude - dLon
        
        return (latitude: mgLat, longitude: mgLon)
    }
    
    // MARK: - GCJ-02转BD-09 (火星坐标转百度坐标)
    static func gcj02ToBd09(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        let z = sqrt(longitude * longitude + latitude * latitude) + 0.00002 * sin(latitude * pi * 3000.0 / 180.0)
        let theta = atan2(latitude, longitude) + 0.000003 * cos(longitude * pi * 3000.0 / 180.0)
        
        let bdLon = z * cos(theta) + 0.0065
        let bdLat = z * sin(theta) + 0.006
        
        return (latitude: bdLat, longitude: bdLon)
    }
    
    // MARK: - BD-09转GCJ-02 (百度坐标转火星坐标)
    static func bd09ToGcj02(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        let x = longitude - 0.0065
        let y = latitude - 0.006
        let z = sqrt(x * x + y * y) - 0.00002 * sin(y * pi * 3000.0 / 180.0)
        let theta = atan2(y, x) - 0.000003 * cos(x * pi * 3000.0 / 180.0)
        
        let gcjLon = z * cos(theta)
        let gcjLat = z * sin(theta)
        
        return (latitude: gcjLat, longitude: gcjLon)
    }
    
    // MARK: - 辅助函数
    private static func transformLat(_ lon: Double, _ lat: Double) -> Double {
        var ret = -100.0 + 2.0 * lon + 3.0 * lat + 0.2 * lat * lat + 0.1 * lon * lat + 0.2 * sqrt(abs(lon))
        ret += (20.0 * sin(6.0 * lon * pi) + 20.0 * sin(2.0 * lon * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(lat * pi) + 40.0 * sin(lat / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(lat / 12.0 * pi) + 320 * sin(lat * pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    private static func transformLon(_ lon: Double, _ lat: Double) -> Double {
        var ret = 300.0 + lon + 2.0 * lat + 0.1 * lon * lon + 0.1 * lon * lat + 0.1 * sqrt(abs(lon))
        ret += (20.0 * sin(6.0 * lon * pi) + 20.0 * sin(2.0 * lon * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(lon * pi) + 40.0 * sin(lon / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(lon / 12.0 * pi) + 300.0 * sin(lon / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
    
    static func outOfChina(latitude: Double, longitude: Double) -> Bool {
        return longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 || latitude > 55.8271
    }
    
    // MARK: - 便捷方法（修复后的版本）
    static func convertCoordinateForDisplay(latitude: Double, longitude: Double, from sourceSystem: CoordinateSystem, to targetSystem: CoordinateSystem) -> (latitude: Double, longitude: Double) {
        
        if sourceSystem == targetSystem {
            return (latitude: latitude, longitude: longitude)
        }
        
        switch (sourceSystem, targetSystem) {
        case (.wgs84, .gcj02):
            return wgs84ToGcj02(latitude: latitude, longitude: longitude)
        case (.gcj02, .wgs84):
            return gcj02ToWgs84(latitude: latitude, longitude: longitude)
        case (.gcj02, .bd09):
            return gcj02ToBd09(latitude: latitude, longitude: longitude)
        case (.bd09, .gcj02):
            return bd09ToGcj02(latitude: latitude, longitude: longitude)
        case (.wgs84, .bd09):
            let gcj02 = wgs84ToGcj02(latitude: latitude, longitude: longitude)
            return gcj02ToBd09(latitude: gcj02.latitude, longitude: gcj02.longitude)
        case (.bd09, .wgs84):
            let gcj02 = bd09ToGcj02(latitude: latitude, longitude: longitude)
            return gcj02ToWgs84(latitude: gcj02.latitude, longitude: gcj02.longitude)
        // 添加默认情况以确保switch语句穷尽
        @unknown default:
            return (latitude: latitude, longitude: longitude)
        }
    }
}

enum CoordinateSystem: CaseIterable {
    case wgs84  // GPS原始坐标系
    case gcj02  // 火星坐标系（中国标准）
    case bd09   // 百度坐标系
    
    var displayName: String {
        switch self {
        case .wgs84:
            return "WGS84 (GPS)"
        case .gcj02:
            return "GCJ-02 (火星)"
        case .bd09:
            return "BD-09 (百度)"
        }
    }
}

// CLLocationCoordinate2D扩展
extension CLLocationCoordinate2D {
    
    // 转换坐标系
    func converted(from sourceSystem: CoordinateSystem, to targetSystem: CoordinateSystem) -> CLLocationCoordinate2D {
        let converted = CoordinateConverter.convertCoordinateForDisplay(
            latitude: self.latitude,
            longitude: self.longitude,
            from: sourceSystem,
            to: targetSystem
        )
        return CLLocationCoordinate2D(latitude: converted.latitude, longitude: converted.longitude)
    }
    
    // 如果你在中国大陆，可以使用这个便捷方法将GPS坐标转换为显示坐标
    func convertedForChineseMap() -> CLLocationCoordinate2D {
        return converted(from: .wgs84, to: .gcj02)
    }
    
    var forMapDisplay: CLLocationCoordinate2D {
        if CoordinateConverter.outOfChina(latitude: latitude, longitude: longitude) {
            return self                      // 海外：不动
        } else {
            return converted(from: .wgs84, to: .gcj02) // 国内：转火星
        }
    }

    
    // 计算两个坐标点之间的距离
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}
