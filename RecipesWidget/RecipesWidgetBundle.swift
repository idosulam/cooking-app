import SwiftUI
import WidgetKit

@main
struct RecipesWidgetBundle: WidgetBundle {
    var body: some Widget {
        CookingLiveActivity()
        TodaysMealWidget()
    }
}
