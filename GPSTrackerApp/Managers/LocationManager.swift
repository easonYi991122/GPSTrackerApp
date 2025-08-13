//
//  LocationManager.swift
//  GPSTrackerApp
// 核心功能：
// 1. CoreLocation框架的封装和管理
// 2. GPS权限请求和状态管理
// 3. 高精度定位配置和后台定位
// 4. 实时位置数据的发布和管理
// 5. 当前记录轨迹的临时存储
// 6. 位置数据过滤和平滑处理
// 7. 坐标系统转换（WGS84 to GCJ02）
//
//  Created by Shuhan Yi on 2025/8/7.
//

import Foundation
import CoreLocation
import CoreMotion
import Combine

// 用于传递位置数据的结构体
struct LocationPointData {
  let latitude: Double
  let longitude: Double
  let timestamp: Date
  let speed: Double
  let altitude: Double
  let horizontalAccuracy: Double
}

class ImprovedLocationManager: NSObject, ObservableObject {
  private let locationManager = CLLocationManager()
  private let motionManager = CMMotionManager()
  
  // 发布的状态属性
  @Published var currentLocation: CLLocation?
  @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
  @Published var isRecording = false
  @Published var currentTrackPoints: [CLLocationCoordinate2D] = []
  @Published var currentSpeed: Double = 0
  @Published var currentDistance: Double = 0
  @Published var recordingStartTime: Date?
  @Published var gpsAccuracy: Double = 999.0  // 初始值设为较大值
  @Published var satelliteCount: Int = 0
  @Published var locationUpdateCount: Int = 0  // 添加位置更新计数器用于调试
  @Published var lastError: String?  // 添加错误信息显示
  
  // 卡尔曼滤波器
  private var kalmanFilter = KalmanLocationFilter()
  
  // 数据缓存和过滤
  private var locationBuffer: [CLLocation] = []
  private var lastValidLocation: CLLocation?
  private var currentTrackLocations: [CLLocation] = []
  
  // 传感器数据
  private var accelerometerData: CMAccelerometerData?
  private var isMoving = false
  
  // 配置参数 - 更严格的数据过滤
  private let minAccuracy: Double = 30.0  // 提高精度要求（米）
  private let maxSpeed: Double = 120.0    // 降低最大合理速度（km/h）
  private let minMovementDistance: Double = 2.0  // 增加最小移动距离（米）
  private let maxLocationAge: TimeInterval = 5.0  // 最大位置数据年龄（秒）
  
  override init() {
      super.init()
      setupLocationManager()
      setupMotionManager()
      
      // 获取当前授权状态
      authorizationStatus = locationManager.authorizationStatus
      print("LocationManager initialized with authorization status: \(authorizationStatus.rawValue)")
  }
  
  private func setupLocationManager() {
      locationManager.delegate = self
      
      // 高精度配置
      locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
      locationManager.distanceFilter = 2.0  // 2米更新一次，减少噪音
      
      // 活动类型设置
      locationManager.activityType = .fitness
      
      print("LocationManager setup completed")
  }
  
  private func setupMotionManager() {
      if motionManager.isAccelerometerAvailable {
          motionManager.accelerometerUpdateInterval = 0.1
          motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
              guard let data = data else { return }
              self?.accelerometerData = data
              self?.updateMovementState(acceleration: data.acceleration)
          }
          print("Motion manager started successfully")
      } else {
          print("Accelerometer not available")
      }
  }
  
  private func updateMovementState(acceleration: CMAcceleration) {
      let magnitude = sqrt(acceleration.x * acceleration.x +
                         acceleration.y * acceleration.y +
                         acceleration.z * acceleration.z)
      
      // 检测是否在移动（考虑重力加速度）
      isMoving = abs(magnitude - 1.0) > 0.15 // 提高移动检测阈值
  }
  
  func requestLocationPermission() {
      print("Requesting location permission...")
      print("Current authorization status: \(authorizationStatus.rawValue)")
      
      switch authorizationStatus {
      case .notDetermined:
          locationManager.requestWhenInUseAuthorization()
      case .denied, .restricted:
          print("Location access denied or restricted")
          lastError = "位置权限被拒绝，请在设置中开启位置权限"
      case .authorizedWhenInUse:
          print("Requesting always authorization...")
          locationManager.requestAlwaysAuthorization()
      case .authorizedAlways:
          print("Already have always authorization")
          requestPreciseLocationIfNeeded()
      @unknown default:
          print("Unknown authorization status")
      }
  }
  
  private func requestPreciseLocationIfNeeded() {
      // iOS 14+ 的精确位置
      if #available(iOS 14.0, *) {
          if locationManager.accuracyAuthorization == .reducedAccuracy {
              print("Requesting precise location...")
              locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "GPS_TRACKING")
          } else {
              print("Already have precise location")
          }
      }
  }
  
  func startRecording() {
      print("Starting recording...")
      print("Authorization status: \(authorizationStatus.rawValue)")
      
      guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
          print("Location permission not granted")
          lastError = "需要位置权限才能开始记录"
          return
      }
      
      isRecording = true
      recordingStartTime = Date()
      currentTrackPoints.removeAll()
      currentTrackLocations.removeAll()
      locationBuffer.removeAll()
      currentDistance = 0
      locationUpdateCount = 0
      lastError = nil
      lastValidLocation = nil
      
      // 重置卡尔曼滤波器
      kalmanFilter.reset()
      
      // 配置后台定位（仅在有Always权限时）
      if authorizationStatus == .authorizedAlways {
          locationManager.allowsBackgroundLocationUpdates = true
          locationManager.pausesLocationUpdatesAutomatically = false
          locationManager.showsBackgroundLocationIndicator = true
      }
      
      locationManager.startUpdatingLocation()
      print("Location updates started")
      
      // 如果可用，启动显著位置变化监测作为备用
      if CLLocationManager.significantLocationChangeMonitoringAvailable() {
          locationManager.startMonitoringSignificantLocationChanges()
          print("Significant location change monitoring started")
      }
      
      // 添加调试定时器，检查是否收到位置更新
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
          if self.locationUpdateCount == 0 {
              print("Warning: No location updates received after 10 seconds")
              self.lastError = "10秒内未收到位置更新，请检查GPS信号"
          }
      }
  }
  
  func stopRecording() {
      print("Stopping recording...")
      isRecording = false
      recordingStartTime = nil
      locationManager.stopUpdatingLocation()
      locationManager.stopMonitoringSignificantLocationChanges()
      
      // 停止后台定位
      if authorizationStatus == .authorizedAlways {
          locationManager.allowsBackgroundLocationUpdates = false
      }
      
      print("Recording stopped. Total locations recorded: \(currentTrackLocations.count)")
  }
  
  // 更严格的数据过滤条件
  private func isValidLocation(_ location: CLLocation) -> Bool {
      // 1. 精度检查 - 更严格的精度要求
      guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= minAccuracy else {
          print("Location rejected due to poor accuracy: \(location.horizontalAccuracy)")
          return false
      }
      
      // 2. 时间检查（忽略缓存的旧数据）
      guard location.timestamp.timeIntervalSinceNow > -maxLocationAge else {
          print("Location rejected due to old timestamp: \(location.timestamp)")
          return false
      }
      
      // 3. 速度合理性检查
      if location.speed > 0 {
          let speedKmh = location.speed * 3.6
          guard speedKmh <= maxSpeed else {
              print("Location rejected due to unreasonable speed: \(speedKmh) km/h")
              return false
          }
      }
      
      // 4. 位置跳跃检查 - 更严格的限制
      if let lastLocation = lastValidLocation {
          let distance = location.distance(from: lastLocation)
          let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
          
          if timeInterval > 0 {
              let calculatedSpeed = (distance / timeInterval) * 3.6 // km/h
              guard calculatedSpeed <= maxSpeed else {
                  print("Location rejected due to calculated speed: \(calculatedSpeed) km/h")
                  return false
              }
              
              // 检查距离跳跃
              guard distance <= 500 else { // 最大500米跳跃
                  print("Location rejected due to large distance jump: \(distance) m")
                  return false
              }
          }
          
          // 静止时的过滤 - 如果不在移动且距离很小，跳过
          if !isMoving && distance < minMovementDistance && timeInterval < 10 {
              print("Location rejected due to minimal movement while stationary")
              return false
          }
      }
      
      // 5. 海拔合理性检查（可选）
      if location.altitude < -500 || location.altitude > 10000 {
          print("Location rejected due to unreasonable altitude: \(location.altitude)")
          return false
      }
      
      return true
  }
  
  // 获取处理后的位置数据 - 包含完整信息和额外验证
  func getCurrentTrackLocationData() -> [LocationPointData] {
      let locationData = currentTrackLocations.map { location in
          LocationPointData(
              latitude: location.coordinate.latitude,
              longitude: location.coordinate.longitude,
              timestamp: location.timestamp,
              speed: max(0, location.speed),
              altitude: location.altitude,
              horizontalAccuracy: location.horizontalAccuracy
          )
      }
      
      // 按时间戳排序确保顺序正确
      return locationData.sorted { $0.timestamp < $1.timestamp }
  }
  
  // 计算属性
  var recordingDuration: String {
      guard let startTime = recordingStartTime else { return "00:00:00" }
      let duration = Date().timeIntervalSince(startTime)
      return TrackUtils.formatTimeInterval(duration)
  }
  
  // 获取GPS状态描述
  var gpsStatusDescription: String {
      if gpsAccuracy <= 5 {
          return "GPS信号优秀"
      } else if gpsAccuracy <= 10 {
          return "GPS信号良好"
      } else if gpsAccuracy <= 20 {
          return "GPS信号一般"
      } else if gpsAccuracy <= 50 {
          return "GPS信号较差"
      } else {
          return "GPS信号很差"
      }
  }
}

// MARK: - CLLocationManagerDelegate
extension ImprovedLocationManager: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      print("Received \(locations.count) location updates")
      locationUpdateCount += locations.count
      
      for location in locations {
          print("Raw location: lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), accuracy=\(location.horizontalAccuracy), speed=\(location.speed)")
          processNewLocation(location)
      }
  }
  
  private func processNewLocation(_ location: CLLocation) {
      // 验证位置数据
      guard isValidLocation(location) else {
          print("Location validation failed")
          return
      }
      
      print("Processing valid location: \(location.coordinate)")
      
      // 添加到缓冲区
      locationBuffer.append(location)
      
      // 保持缓冲区大小
      if locationBuffer.count > 5 {
          locationBuffer.removeFirst()
      }
      
      // 卡尔曼滤波处理
      let filteredLocation = kalmanFilter.filter(location: location)
      
      DispatchQueue.main.async {
          self.currentLocation = filteredLocation
          self.gpsAccuracy = location.horizontalAccuracy
          
          // 更新速度（使用滤波后的数据）
          if location.speed >= 0 {
              self.currentSpeed = min(location.speed * 3.6, self.maxSpeed) // 转换为km/h并限制最大值
          } else {
              // 基于位置计算速度
              if let lastLocation = self.lastValidLocation,
                 lastLocation.timestamp != filteredLocation.timestamp {
                  let distance = filteredLocation.distance(from: lastLocation)
                  let timeInterval = filteredLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
                  if timeInterval > 0 {
                      let calculatedSpeed = (distance / timeInterval) * 3.6
                      self.currentSpeed = min(calculatedSpeed, self.maxSpeed)
                  }
              }
          }
          
          if self.isRecording {
              self.currentTrackPoints.append(filteredLocation.coordinate.forMapDisplay)
              self.currentTrackLocations.append(filteredLocation)
              
              print("Added location to track. Total points: \(self.currentTrackPoints.count)")
              
              // 计算总距离
              if let lastLocation = self.lastValidLocation {
                  let distance = filteredLocation.distance(from: lastLocation)
                  // 只有合理的距离才累加
                  if distance <= 200 { // 最大200米的单次移动
                      self.currentDistance += distance / 1000.0 // 转换为km
                  }
              }
          }
          
          self.lastValidLocation = filteredLocation
      }
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
      print("Authorization status changed to: \(status.rawValue)")
      
      DispatchQueue.main.async {
          self.authorizationStatus = status
          
          switch status {
          case .notDetermined:
              print("Location permission not determined")
          case .denied, .restricted:
              print("Location permission denied or restricted")
              self.lastError = "位置权限被拒绝"
          case .authorizedWhenInUse:
              print("Location permission granted for when in use")
              self.requestPreciseLocationIfNeeded()
              // 可以考虑请求Always权限
              DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                  self.locationManager.requestAlwaysAuthorization()
              }
          case .authorizedAlways:
              print("Location permission granted for always")
              self.requestPreciseLocationIfNeeded()
          @unknown default:
              print("Unknown authorization status")
          }
      }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
      print("Location manager failed with error: \(error)")
      
      DispatchQueue.main.async {
          if let clError = error as? CLError {
              switch clError.code {
              case .denied:
                  self.lastError = "位置访问被拒绝"
              case .network:
                  self.lastError = "网络错误"
              case .locationUnknown:
                  self.lastError = "无法确定位置"
              default:
                  self.lastError = "位置错误: \(clError.localizedDescription)"
              }
          } else {
              self.lastError = "位置错误: \(error.localizedDescription)"
          }
      }
  }
}

// MARK: - 卡尔曼滤波器
class KalmanLocationFilter {
  private var isInitialized = false
  private var lastLocation: CLLocation?
  private var variance: Double = -1
  
  private let minAccuracy: Double = 1.0
  
  func filter(location: CLLocation) -> CLLocation {
      if variance < 0 {
          //
          // 第一次初始化
          variance = location.horizontalAccuracy * location.horizontalAccuracy
          isInitialized = true
          lastLocation = location
          return location
      }
      
      guard let lastLoc = lastLocation else {
          lastLocation = location
          return location
      }
      
      let timeInterval = location.timestamp.timeIntervalSince(lastLoc.timestamp)
      
      if timeInterval > 0 {
          // 预测方差增加
          variance += timeInterval * timeInterval * 4 // 4 m²/s²的过程噪声
      }
      
      // 卡尔曼增益
      let accuracy = max(location.horizontalAccuracy, minAccuracy)
      let kalmanGain = variance / (variance + accuracy * accuracy)
      
      // 更新位置
      let newLat = lastLoc.coordinate.latitude + kalmanGain * (location.coordinate.latitude - lastLoc.coordinate.latitude)
      let newLon = lastLoc.coordinate.longitude + kalmanGain * (location.coordinate.longitude - lastLoc.coordinate.longitude)
      
      // 更新方差
      variance = (1 - kalmanGain) * variance
      
      let filteredLocation = CLLocation(
          coordinate: CLLocationCoordinate2D(latitude: newLat, longitude: newLon),
          altitude: location.altitude,
          horizontalAccuracy: location.horizontalAccuracy,
          verticalAccuracy: location.verticalAccuracy,
          course: location.course,
          speed: location.speed,
          timestamp: location.timestamp
      )
      
      lastLocation = filteredLocation
      return filteredLocation
  }
  
  func reset() {
      isInitialized = false
      lastLocation = nil
      variance = -1
  }
}

// 关联关系：
// ← ContentView.swift (被创建和注入)
// → MainView.swift (提供GPS数据和控制方法)
// → TrackUtils.swift (使用工具函数格式化时间)
// ↔ DataModels.swift (提供数据用于创建LocationPoint)
