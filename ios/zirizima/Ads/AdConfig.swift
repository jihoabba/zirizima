import Foundation

enum AdConfig {
    static let testBanner = "ca-app-pub-3940256099942544/2934735716"

    #if DEBUG
    static let homeBanner = testBanner
    static let detailBanner = testBanner
    #else
    static let homeBanner = "ca-app-pub-9339911776645987/3371155987"
    static let detailBanner = "ca-app-pub-9339911776645987/3371155987"
    #endif
}
