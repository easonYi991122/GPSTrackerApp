//
//  ExportManager.swift
//  GPSTrackerApp
//
//  Created by Shuhan Yi on 2025/8/7.
//

import Foundation
import SwiftUI

class ExportManager: ObservableObject {
    @Published var isExporting = false
    @Published var exportError: String?
    
    func exportTrackToCSV(_ track: Track) -> URL? {
        guard !track.locations.isEmpty else {
            exportError = "轨迹没有位置数据"
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: track.startTime)
        
        let fileName = "轨迹_\(timestamp).csv"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        var csvContent = "时间,纬度,经度,速度(km/h),海拔(m),精度(m)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for location in track.locations {
            let timeString = dateFormatter.string(from: location.timestamp)
            let speedKmh = max(0, location.speed * 3.6)
            
            csvContent += "\(timeString),\(location.latitude),\(location.longitude),\(String(format: "%.2f", speedKmh)),\(String(format: "%.1f", location.altitude)),\(String(format: "%.1f", location.horizontalAccuracy))\n"
        }
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("CSV文件已保存到: \(fileURL.path)")
            return fileURL
        } catch {
            exportError = "导出失败: \(error.localizedDescription)"
            print("CSV导出错误: \(error)")
            return nil
        }
    }
}
