//
//  ContentView.swift
//  GPSTrackerApp
//  核心功能：
//  1. 管理TabView或NavigationView的主要导航结构
//  2. 维护全局的LocationManager实例
//  3. 处理不同界面间的状态传递
//
//  Created by Shuhan Yi on 2025/8/7.
//

// 实现思路：
import SwiftUI

struct ContentView: View {
  @StateObject private var locationManager = ImprovedLocationManager()
  @State private var selectedTab = 0
  
  var body: some View {
      TabView(selection: $selectedTab) {
          // 主记录界面
          MainView()
              .environmentObject(locationManager)
              .tabItem { Label("记录", systemImage: "location") }
              .tag(0)
          
          // 历史记录界面
          HistoryView()
              .environmentObject(locationManager)
              .tabItem { Label("历史", systemImage: "list.bullet") }
              .tag(1)
      }
  }
}

// 关联关系：
// ← GPSTrackerApp.swift (接收数据容器)
// → MainView.swift (传递ImprovedLocationManager)
// → HistoryView.swift (传递ImprovedLocationManager)
