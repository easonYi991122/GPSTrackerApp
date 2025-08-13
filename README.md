# GPS Tracker App 📍

[English](#english) | [中文](#中文)

---

## 中文

### 项目简介

GPS Tracker App 是一款专业的iOS轨迹记录应用，能够精确记录和管理用户的GPS轨迹数据。应用采用WGS-84坐标系统进行数据存储，使用GCJ-02坐标系统进行地图显示，确保在中国地区的地图显示准确性。

### 核心功能

- **🎯 实时轨迹记录**：高精度GPS定位，实时记录位置轨迹
- **📊 多维度数据采集**：记录经度、纬度、海拔、速度、时间戳
- **💾 历史轨迹存储**：使用SwiftData进行本地数据持久化
- **🗺️ 轨迹可视化**：在地图上实时显示和回放轨迹路线
- **📤 数据导出**：支持GPX、CSV格式导出
- **🔧 智能数据过滤**：卡尔曼滤波算法优化GPS数据精度

### 技术特点

#### 坐标系统
- **存储格式**：WGS-84（世界大地坐标系）
- **显示格式**：GCJ-02（火星坐标系，适配中国地图）
- **自动转换**：内置坐标系转换工具

#### 定位技术
- 高精度GPS定位（精度要求≤30米）
- 卡尔曼滤波算法数据平滑
- 智能数据验证和异常过滤
- 后台定位支持

#### 数据管理
- SwiftData本地数据库
- 实时数据缓存和优化
- 轨迹统计分析（距离、速度、时长等）

### 项目结构

```
GPSTrackerApp/
├── Managers/
│   ├── LocationManager.swift      # 位置管理器
│   └── ExportManager.swift        # 数据导出管理
├── Models/
│   └── DataModels.swift           # SwiftData数据模型
├── Utils/
│   ├── CoordinateConverter.swift  # 坐标系转换工具
│   └── TrackUtils.swift           # 轨迹计算工具
├── Views/
│   ├── MainView.swift             # 实时记录界面
│   ├── HistoryView.swift          # 历史轨迹列表
│   └── TrackDetailView.swift      # 轨迹详情页面
├── ContentView.swift              # 主视图容器
├── GPSTrackerAppApp.swift         # 应用入口
└── Info.plist                     # 应用配置
```

### 主要组件说明

#### 1. LocationManager.swift
- 核心定位服务管理
- GPS权限处理
- 实时位置数据发布
- 卡尔曼滤波数据优化
- 后台定位支持

#### 2. DataModels.swift
- SwiftData数据模型定义
- Track（轨迹）和LocationPoint（位置点）关系
- 数据验证和计算属性

#### 3. CoordinateConverter.swift
- WGS84 ↔ GCJ-02 坐标转换
- BD-09坐标系支持
- 中国境内坐标偏移处理

#### 4. TrackUtils.swift
- 轨迹距离计算
- 速度和时间统计
- 海拔变化分析
- 数据导出功能

### 系统要求

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- 支持GPS的iOS设备

### 权限要求

应用需要以下权限：
- **位置权限**：`NSLocationWhenInUseUsageDescription`
- **后台位置**：`NSLocationAlwaysAndWhenInUseUsageDescription`
- **精确位置**：`NSLocationTemporaryUsageDescriptionDictionary`

### 安装和运行

1. **克隆项目**
 ```bash
 git clone https://github.com/你的用户名/GPSTrackerApp.git
 cd GPSTrackerApp
 ```

2. **打开项目**
 ```bash
 open GPSTrackerApp.xcodeproj
 ```

3. **配置开发者账户**
 - 在Xcode中设置你的开发者账户
 - 修改Bundle Identifier

4. **运行应用**
 - 选择真机设备（GPS功能需要真机测试）
 - 点击运行按钮

### 使用说明

#### 开始记录轨迹
1. 打开应用，授予位置权限
2. 在主界面点击"开始记录"按钮
3. 应用将实时显示当前位置和轨迹

#### 查看历史轨迹
1. 切换到"历史"标签页
2. 选择要查看的轨迹
3. 在详情页面查看完整轨迹和统计信息

#### 导出轨迹数据
1. 在轨迹详情页面点击"导出"按钮
2. 选择导出格式（GPX、CSV）
3. 通过分享菜单保存或发送文件

### 数据格式

#### GPX格式示例
```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
<trk>
  <name>轨迹名称</name>
  <trkseg>
    <trkpt lat="39.9042" lon="116.4074">
      <ele>50.0</ele>
      <time>2025-08-13T10:00:00Z</time>
      <speed>5.5</speed>
    </trkpt>
  </trkseg>
</trk>
</gpx>
```

---

## English

### Project Overview

GPS Tracker App is a professional iOS trajectory recording application that accurately captures and manages user GPS track data. The app uses the WGS-84 coordinate system for data storage and GCJ-02 coordinate system for map display, ensuring accurate map visualization in China.

### Core Features

- **🎯 Real-time Track Recording**: High-precision GPS positioning with real-time trajectory recording
- **📊 Multi-dimensional Data Collection**: Records longitude, latitude, altitude, speed, and timestamps
- **💾 Historical Track Storage**: Local data persistence using SwiftData
- **🗺️ Track Visualization**: Real-time display and playback of track routes on maps
- **📤 Data Export**: Supports multiple formats including GPX, and CSV
- **🔧 Smart Data Filtering**: Kalman filter algorithm for GPS data accuracy optimization

### Technical Highlights

#### Coordinate Systems
- **Storage Format**: WGS-84 (World Geodetic System)
- **Display Format**: GCJ-02 (Mars Coordinate System for China maps)
- **Auto Conversion**: Built-in coordinate system conversion tools

#### Positioning Technology
- High-precision GPS positioning (accuracy requirement ≤30 meters)
- Kalman filter algorithm for data smoothing
- Smart data validation and anomaly filtering
- Background location support

#### Data Management
- SwiftData local database
- Real-time data caching and optimization
- Track statistics analysis (distance, speed, duration, etc.)

### Project Structure

```
GPSTrackerApp/
├── Managers/
│   ├── LocationManager.swift      # Location manager
│   └── ExportManager.swift        # Data export manager
├── Models/
│   └── DataModels.swift           # SwiftData data models
├── Utils/
│   ├── CoordinateConverter.swift  # Coordinate system converter
│   └── TrackUtils.swift           # Track calculation utilities
├── Views/
│   ├── MainView.swift             # Real-time recording interface
│   ├── HistoryView.swift          # Historical tracks list
│   └── TrackDetailView.swift      # Track detail page
├── ContentView.swift              # Main view container
├── GPSTrackerAppApp.swift         # App entry point
└── Info.plist                     # App configuration
```

### System Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- GPS-enabled iOS device

### Required Permissions

The app requires the following permissions:
- **Location Permission**: `NSLocationWhenInUseUsageDescription`
- **Background Location**: `NSLocationAlwaysAndWhenInUseUsageDescription`
- **Precise Location**: `NSLocationTemporaryUsageDescriptionDictionary`

### Installation and Setup

1. **Clone the project**
 ```bash
 git clone https://github.com/yourusername/GPSTrackerApp.git
 cd GPSTrackerApp
 ```

2. **Open the project**
 ```bash
 open GPSTrackerApp.xcodeproj
 ```

3. **Configure developer account**
 - Set up your developer account in Xcode
 - Modify the Bundle Identifier

4. **Run the app**
 - Select a physical device (GPS functionality requires real device testing)
 - Click the run button

### Usage Instructions

#### Start Recording Tracks
1. Open the app and grant location permissions
2. Tap the "Start Recording" button on the main interface
3. The app will display current location and track in real-time

#### View Historical Tracks
1. Switch to the "History" tab
2. Select a track to view
3. View complete track and statistics on the detail page

#### Export Track Data
1. Tap the "Export" button on the track detail page
2. Choose export format (GPX, CSV)
3. Save or send files through the share menu

---

### Contact

- **Author**: Shuhan Yi
- **Email**: [enian991122@gmail.com]
- **GitHub**: [@easonYi991122](https://github.com/easonYi991122)

### Acknowledgments

- Thanks to the CoreLocation framework
- Thanks to the SwiftData framework
- Thanks to the MapKit framework
