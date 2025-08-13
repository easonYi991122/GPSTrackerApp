//
//  GPSTrackerAppApp.swift
//  GPSTrackerApp
//  核心功能：
//  1. 配置SwiftData模型容器
//  2. 设置App生命周期管理
//  3. 初始化全局环境对象
//
//  Created by Shuhan Yi on 2025/8/7.
//

import SwiftUI
import SwiftData

@main
struct GPSTrackerAppApp: App {
    
    // 配置SwiftData容器，包含Track和LocationPoint模型
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: Track.self, LocationPoint.self)
        } catch {
            fatalError("Failed to initialize ModelContainer")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container) // 注入数据容器
        }
    }
}

// 关联关系：
// → ContentView.swift (提供数据容器环境)
