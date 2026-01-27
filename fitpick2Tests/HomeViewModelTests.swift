//test for HomeView
//commenting out for now, just a placeholder
/*
import XCTest
@testable import fitpick2

final class HomeViewModelTests: XCTestCase {

    func testGapDetection_whenFormalEventAndNoFormalShoes_setsGapMessage() {
        let mockFirestore = MockFirestoreManager()
        let mockCalendar = MockCalendarManager()

        // Configure mocks
        mockFirestore.heroImageNameToReturn = "hero_asset_test"
        mockFirestore.wardrobeCountsToReturn = [:] // no shoes
        mockCalendar.nextEventToReturn = "Board Meeting — Formal"

        let expectation = XCTestExpectation(description: "Gap detection should set message")

        let vm = HomeViewModel(firestore: mockFirestore, calendar: mockCalendar)

        // Wait a short while for async work to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if vm.gapDetectionMessage != nil {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(vm.gapDetectionMessage)
    }
}

// Mock implementations
final class MockFirestoreManager: FirestoreManager {
    var heroImageNameToReturn: String? = nil
    var wardrobeCountsToReturn: [String: Int] = [:]

    override func fetchHeroImageName(completion: @escaping (String?) -> Void) {
        completion(heroImageNameToReturn)
    }

    override func fetchWardrobeCounts(completion: @escaping ([String : Int]) -> Void) {
        completion(wardrobeCountsToReturn)
    }
}

final class MockCalendarManager: CalendarManager {
    var nextEventToReturn: String? = nil

    override func fetchNextEvent(completion: @escaping (String?) -> Void) {
        completion(nextEventToReturn)
    }
}
*/