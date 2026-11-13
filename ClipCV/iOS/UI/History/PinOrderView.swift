import SwiftData
import SwiftUI

struct PinOrderView: View {
    @Environment(AppRuntime.self) private var runtime
    @Query(filter: #Predicate<ClipboardItem> { $0.pinned }, sort: \ClipboardItem.pinOrder) private var pins: [ClipboardItem]

    var body: some View {
        List {
            ForEach(pins) { Text($0.displayTitle).lineLimit(2).listRowBackground(ClipStyle.card) }
                .onMove { offsets, destination in runtime.perform { try runtime.history.movePins(from: offsets, to: destination) } }
        }.scrollContentBackground(.hidden).clipPage().navigationTitle("钉选排序")
            .toolbar(.visible, for: .navigationBar).environment(\.editMode, .constant(.active))
    }
}
