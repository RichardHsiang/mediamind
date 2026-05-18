import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("历史记录")
                    .font(.system(size: 28, weight: .bold))

                if tasks.isEmpty {
                    emptyState
                } else {
                    ForEach(tasks) { task in
                        TaskRow(task: task)
                    }
                }
            }
            .padding(40)
        }
        .background(Color.appleBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.appleGray)

            Text("暂无历史记录")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.appleGray)

            Text("处理过的任务将显示在这里")
                .font(.system(size: 14))
                .foregroundColor(.appleGray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
