import WidgetKit
import SwiftUI

@main
struct PhilipsWidgetBundle: WidgetBundle {
    var body: some Widget {
        FavoriteTVWidget()
        QuickVolumeWidget()
        OpenAppWidget()
        SleepTimerWidget()
        NowWatchingLiveActivity()
    }
}
