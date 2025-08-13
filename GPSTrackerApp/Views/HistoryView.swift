//
//  HistoryView.swift
//  GPSTrackerApp
// 核心功能：
// 1. 显示所有已保存轨迹的列表
// 2. 轨迹基本信息展示（名称、日期、距离等）
// 3. 轨迹删除功能
// 4. 导航到轨迹详情页面
//
//  Created by Shuhan Yi on 2025/8/7.
//


// 实现思路：
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Track.startTime, order: .reverse) private var tracks: [Track]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tracks) { track in
                    NavigationLink(destination: TrackDetailView(track: track)) {
                        TrackRowView(track: track)
                    }
                }
                .onDelete(perform: deleteTracks)
            }
            .navigationTitle("历史轨迹")
        }
    }
    
    private func deleteTracks(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tracks[index])
        }
        try? modelContext.save()
    }
}

struct TrackRowView: View {
    let track: Track
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.name)
                .font(.headline)
            
            HStack {
                Text(track.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let distance = TrackUtils.calculateDistance(for: track) {
                    Text("\(distance, specifier: "%.2f") km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// 关联关系：
// ← ContentView.swift (接收导航环境)
// ↔ DataModels.swift (查询Track数据)
// → TrackDetailView.swift (导航到详情页面)
// → TrackUtils.swift (计算轨迹统计信息)

