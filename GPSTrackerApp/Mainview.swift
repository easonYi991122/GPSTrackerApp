//
//  Mainview.swift
//  GPSTrackerApp
// 核心功能：
// 1. 实时地图显示和当前位置跟踪
// 2. 开始/停止GPS记录控制
// 3. 实时轨迹绘制和可视化
// 4. 当前记录状态和统计信息显示
//
//  Created by Shuhan Yi on 2025/8/7.
//

// 实现思路：
import SwiftUI
import MapKit

struct MainView: View {
  @EnvironmentObject var locationManager: ImprovedLocationManager
  @Environment(\.modelContext) private var modelContext
  @State private var currentTrack: Track?
  @State private var isRecording = false
  @State private var cameraPosition: MapCameraPosition = .automatic
  
  var body: some View {
      VStack(spacing: 0) {
          // GPS状态指示器
          VStack(spacing: 4) {
              HStack {
                  Circle()
                      .fill(locationManager.gpsAccuracy <= 10 ? .green :
                            locationManager.gpsAccuracy <= 20 ? .yellow : .red)
                      .frame(width: 10, height: 10)
                  
                  Text(locationManager.gpsStatusDescription)
                      .font(.caption)
                  
                  Spacer()
                  
                  Text("精度: \(locationManager.gpsAccuracy, specifier: "%.1f")m")
                      .font(.caption)
              }
              
              // 调试信息
              HStack {
                  Text("权限: \(authorizationStatusText)")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  
                  Spacer()
                  
                  Text("更新次数: \(locationManager.locationUpdateCount)")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  
                  Spacer()
                  
                  Text("轨迹点: \(locationManager.currentTrackPoints.count)")
                      .font(.caption2)
                      .foregroundColor(.secondary)
              }
              
              // 错误信息显示
              if let error = locationManager.lastError {
                  Text(error)
                      .font(.caption2)
                      .foregroundColor(.red)
                      .multilineTextAlignment(.center)
              }
          }
          .padding(.horizontal)
          .padding(.vertical, 8)
          .background(.ultraThinMaterial)
          
          // 主要内容区域
          ZStack {
              // 地图视图 - 占据大部分屏幕
              Map(position: $cameraPosition) {
                  // 显示当前位置
                  if let location = locationManager.currentLocation {
                      Annotation("当前位置", coordinate: location.coordinate.forMapDisplay) {
                          Circle().fill(.blue).frame(width: 12, height: 12)
                      }
                  }
                  
                  // 绘制当前记录的轨迹
                  if !locationManager.currentTrackPoints.isEmpty {
                      MapPolyline(coordinates: locationManager.currentTrackPoints)
                          .stroke(.red, lineWidth: 3)
                  }
              }
              
              // 底部控制面板
              VStack {
                  Spacer()
                  
                  // 当前统计信息
                  if isRecording {
                      HStack {
                          VStack {
                              Text("速度")
                              Text("\(locationManager.currentSpeed, specifier: "%.1f") km/h")
                          }
                          Spacer()
                          VStack {
                              Text("距离")
                              Text("\(locationManager.currentDistance, specifier: "%.2f") km")
                          }
                          Spacer()
                          VStack {
                              Text("时长")
                              Text(locationManager.recordingDuration)
                          }
                      }
                      .padding()
                      .background(.ultraThinMaterial)
                      .cornerRadius(12)
                  }
                  
                  // 记录控制按钮
                  Button(action: toggleRecording) {
                      Text(isRecording ? "停止记录" : "开始记录")
                          .font(.title2)
                          .foregroundColor(.white)
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(isRecording ? .red : .green)
                          .cornerRadius(12)
                  }
                  .disabled(locationManager.authorizationStatus == .denied ||
                           locationManager.authorizationStatus == .restricted)
                  
                  // 权限请求按钮
                  if locationManager.authorizationStatus == .notDetermined ||
                     locationManager.authorizationStatus == .denied {
                      Button("请求位置权限") {
                          locationManager.requestLocationPermission()
                      }
                      .font(.caption)
                      .padding(.vertical, 8)
                      .padding(.horizontal, 16)
                      .background(.blue)
                      .foregroundColor(.white)
                      .cornerRadius(8)
                  }
              }
              .padding()
          }
      }
      .onAppear {
          locationManager.requestLocationPermission()
      }
  }
  
  private var authorizationStatusText: String {
      switch locationManager.authorizationStatus {
      case .notDetermined: return "未确定"
      case .denied: return "拒绝"
      case .restricted: return "受限"
      case .authorizedWhenInUse: return "使用时"
      case .authorizedAlways: return "始终"
      @unknown default: return "未知"
      }
  }
  
  private func toggleRecording() {
      if isRecording {
          stopRecording()
      } else {
          startRecording()
      }
  }
  
  private func startRecording() {
      currentTrack = Track(startTime: Date())
      locationManager.startRecording()
      isRecording = true
      print("开始记录轨迹: \(currentTrack?.id.uuidString ?? "unknown")")
  }
  
  private func stopRecording() {
      guard let track = currentTrack else {
          print("错误：当前轨迹为空")
          return
      }
      
      print("停止记录轨迹，开始保存数据...")
      
      // 设置结束时间
      track.endTime = Date()
      
      // 从LocationManager获取完整的位置数据并进行数据清理
      let locationData = locationManager.getCurrentTrackLocationData()
      print("获取到位置数据点数量: \(locationData.count)")
      
      // 数据清理和验证
      let cleanedLocationData = cleanLocationData(locationData)
      print("清理后位置数据点数量: \(cleanedLocationData.count)")
      
      // 确保有有效数据
      guard !cleanedLocationData.isEmpty else {
          print("警告：没有有效的位置数据")
          locationManager.stopRecording()
          isRecording = false
          currentTrack = nil
          return
      }
      
      // 创建LocationPoint对象并建立关系
      track.locations.removeAll() // 清空现有数据
      
      for data in cleanedLocationData {
          let locationPoint = LocationPoint(
              latitude: data.latitude,
              longitude: data.longitude,
              timestamp: data.timestamp,
              speed: max(0, data.speed), // 确保速度非负
              altitude: data.altitude,
              horizontalAccuracy: data.horizontalAccuracy
          )
          
          // 建立双向关系
          locationPoint.track = track
          track.locations.append(locationPoint)
      }
      
      // 验证数据完整性
      let calculatedDistance = TrackUtils.calculateDistance(for: track) ?? 0
      let calculatedDuration = track.duration ?? 0
      let calculatedAvgSpeed = TrackUtils.calculateAverageSpeed(for: track) ?? 0
      
      print("轨迹统计信息:")
      print("- 距离: \(calculatedDistance) km")
      print("- 时长: \(calculatedDuration) 秒")
      print("- 平均速度: \(calculatedAvgSpeed) km/h")
      print("- 位置点数量: \(track.locations.count)")
      
      // 数据合理性检查
      if calculatedAvgSpeed > 100 { // 如果平均速度超过100km/h，可能有问题
          print("警告：计算出的平均速度异常高: \(calculatedAvgSpeed) km/h")
          // 可以选择不保存或进一步清理数据
      }
      
      // 保存到数据库
      do {
          modelContext.insert(track)
          try modelContext.save()
          print("轨迹保存成功")
      } catch {
          print("保存轨迹失败: \(error)")
      }
      
      // 清理状态
      locationManager.stopRecording()
      isRecording = false
      currentTrack = nil
  }
  
  // 新增：数据清理函数
  private func cleanLocationData(_ locationData: [LocationPointData]) -> [LocationPointData] {
      guard locationData.count > 1 else { return locationData }
      
      var cleanedData: [LocationPointData] = []
      var previousData: LocationPointData?
      
      for data in locationData {
          // 基本验证
          guard data.horizontalAccuracy > 0 && data.horizontalAccuracy <= 50 else {
              print("跳过精度差的点: \(data.horizontalAccuracy)")
              continue
          }
          
          // 时间验证（确保时间戳递增）
          if let prev = previousData {
              let timeInterval = data.timestamp.timeIntervalSince(prev.timestamp)
              guard timeInterval > 0 else {
                  print("跳过时间戳异常的点")
                  continue
              }
              
              // 距离和速度验证
              let distance = calculateDistance(
                  lat1: prev.latitude, lon1: prev.longitude,
                  lat2: data.latitude, lon2: data.longitude
              )
              
              if timeInterval > 0 {
                  let calculatedSpeed = (distance / timeInterval) * 3.6 // km/h
                  
                  // 跳过速度异常的点（超过150km/h）
                  if calculatedSpeed > 150 {
                      print("跳过速度异常的点: \(calculatedSpeed) km/h")
                      continue
                  }
                  
                  // 跳过距离跳跃过大的点（超过1km）
                  if distance > 1000 {
                      print("跳过距离跳跃过大的点: \(distance) m")
                      continue
                  }
              }
          }
          
          cleanedData.append(data)
          previousData = data
      }
      
      return cleanedData
  }
  
  // 新增：距离计算辅助函数
  private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
      let location1 = CLLocation(latitude: lat1, longitude: lon1)
      let location2 = CLLocation(latitude: lat2, longitude: lon2)
      return location1.distance(from: location2)
  }
}

#Preview {
  MainView()
      .environmentObject(ImprovedLocationManager())
      .modelContainer(for: [Track.self, LocationPoint.self], inMemory: true)
}

#Preview("Recording State") {
  let locationManager = ImprovedLocationManager()
  return MainView()
      .environmentObject(locationManager)
      .modelContainer(for: [Track.self, LocationPoint.self], inMemory: true)
}

// 关联关系：
// ← ContentView.swift (接收ImprovedLocationManager)
// ↔ ImprovedLocationManager.swift (获取GPS数据，控制记录状态)
// ↔ DataModels.swift (创建和保存Track对象)
// → TrackUtils.swift (计算距离和统计信息)
