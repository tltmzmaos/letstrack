import Foundation
import SwiftData

// MARK: - Smart Category Service

@MainActor
final class SmartCategoryService {
    static let shared = SmartCategoryService()

    private init() {}

    // MARK: - Keyword Mapping (Built-in)

    /// Built-in keyword to category icon mapping
    private let keywordToCategoryIcon: [String: String] = [
        // Food & Drink - Korean
        "스타벅스": "fork.knife",
        "카페": "fork.knife",
        "커피": "fork.knife",
        "투썸": "fork.knife",
        "이디야": "fork.knife",
        "맥도날드": "fork.knife",
        "버거킹": "fork.knife",
        "롯데리아": "fork.knife",
        "bbq": "fork.knife",
        "bhc": "fork.knife",
        "치킨": "fork.knife",
        "피자": "fork.knife",
        "도미노": "fork.knife",
        "파파존스": "fork.knife",
        "배달의민족": "fork.knife",
        "배민": "fork.knife",
        "요기요": "fork.knife",
        "쿠팡이츠": "fork.knife",
        "편의점": "fork.knife",
        "gs25": "fork.knife",
        "cu": "fork.knife",
        "세븐일레븐": "fork.knife",
        "이마트24": "fork.knife",
        "마트": "fork.knife",
        "이마트": "fork.knife",
        "홈플러스": "fork.knife",
        "코스트코": "fork.knife",
        "식당": "fork.knife",
        "음식": "fork.knife",
        "점심": "fork.knife",
        "저녁": "fork.knife",
        "아침": "fork.knife",
        "식비": "fork.knife",
        "밥": "fork.knife",

        // Food & Drink - English
        "starbucks": "fork.knife",
        "cafe": "fork.knife",
        "coffee": "fork.knife",
        "mcdonald": "fork.knife",
        "burger": "fork.knife",
        "pizza": "fork.knife",
        "chicken": "fork.knife",
        "restaurant": "fork.knife",
        "food": "fork.knife",
        "lunch": "fork.knife",
        "dinner": "fork.knife",
        "breakfast": "fork.knife",
        "grocery": "fork.knife",
        "supermarket": "fork.knife",
        "uber eats": "fork.knife",
        "doordash": "fork.knife",

        // Transport - Korean
        "택시": "car.fill",
        "카카오택시": "car.fill",
        "타다": "car.fill",
        "버스": "car.fill",
        "지하철": "car.fill",
        "교통": "car.fill",
        "주유": "car.fill",
        "주유소": "car.fill",
        "기름": "car.fill",
        "고속도로": "car.fill",
        "톨비": "car.fill",
        "주차": "car.fill",
        "주차비": "car.fill",
        "주차장": "car.fill",
        "티머니": "car.fill",
        "ktx": "car.fill",
        "srt": "car.fill",
        "기차": "car.fill",
        "비행기": "car.fill",
        "항공": "car.fill",

        // Transport - English
        "taxi": "car.fill",
        "uber": "car.fill",
        "lyft": "car.fill",
        "bus": "car.fill",
        "subway": "car.fill",
        "metro": "car.fill",
        "gas": "car.fill",
        "parking": "car.fill",
        "toll": "car.fill",
        "flight": "car.fill",
        "airline": "car.fill",
        "train": "car.fill",

        // Shopping - Korean
        "쿠팡": "bag.fill",
        "네이버쇼핑": "bag.fill",
        "11번가": "bag.fill",
        "지마켓": "bag.fill",
        "옥션": "bag.fill",
        "무신사": "bag.fill",
        "올리브영": "bag.fill",
        "다이소": "bag.fill",
        "쇼핑": "bag.fill",
        "옷": "bag.fill",
        "의류": "bag.fill",
        "신발": "bag.fill",
        "화장품": "bag.fill",
        "백화점": "bag.fill",
        "아울렛": "bag.fill",

        // Shopping - English
        "amazon": "bag.fill",
        "shopping": "bag.fill",
        "clothes": "bag.fill",
        "shoes": "bag.fill",
        "walmart": "bag.fill",
        "target": "bag.fill",
        "costco": "bag.fill",

        // Housing - Korean
        "월세": "house.fill",
        "전세": "house.fill",
        "관리비": "house.fill",
        "전기세": "house.fill",
        "가스비": "house.fill",
        "수도세": "house.fill",
        "인터넷": "house.fill",

        // Housing - English
        "rent": "house.fill",
        "utility": "house.fill",
        "electric": "house.fill",
        "water": "house.fill",

        // Telecom - Korean
        "통신비": "phone.fill",
        "핸드폰": "phone.fill",
        "휴대폰": "phone.fill",
        "skt": "phone.fill",
        "kt": "phone.fill",
        "lg유플러스": "phone.fill",
        "알뜰폰": "phone.fill",

        // Telecom - English
        "phone": "phone.fill",
        "mobile": "phone.fill",
        "cellular": "phone.fill",
        "verizon": "phone.fill",
        "at&t": "phone.fill",
        "t-mobile": "phone.fill",

        // Medical - Korean
        "병원": "cross.case.fill",
        "약국": "cross.case.fill",
        "약": "cross.case.fill",
        "의원": "cross.case.fill",
        "치과": "cross.case.fill",
        "안과": "cross.case.fill",
        "피부과": "cross.case.fill",
        "한의원": "cross.case.fill",
        "건강검진": "cross.case.fill",

        // Medical - English
        "hospital": "cross.case.fill",
        "pharmacy": "cross.case.fill",
        "doctor": "cross.case.fill",
        "clinic": "cross.case.fill",
        "medicine": "cross.case.fill",
        "dental": "cross.case.fill",

        // Education - Korean
        "학원": "book.fill",
        "교육": "book.fill",
        "학비": "book.fill",
        "등록금": "book.fill",
        "책": "book.fill",
        "교재": "book.fill",
        "강의": "book.fill",
        "인강": "book.fill",
        "클래스101": "book.fill",

        // Education - English
        "school": "book.fill",
        "tuition": "book.fill",
        "course": "book.fill",
        "book": "book.fill",
        "education": "book.fill",
        "udemy": "book.fill",
        "coursera": "book.fill",

        // Entertainment - Korean
        "영화": "gamecontroller.fill",
        "cgv": "gamecontroller.fill",
        "롯데시네마": "gamecontroller.fill",
        "메가박스": "gamecontroller.fill",
        "넷플릭스": "gamecontroller.fill",
        "유튜브": "gamecontroller.fill",
        "왓챠": "gamecontroller.fill",
        "웨이브": "gamecontroller.fill",
        "디즈니": "gamecontroller.fill",
        "게임": "gamecontroller.fill",
        "스팀": "gamecontroller.fill",
        "닌텐도": "gamecontroller.fill",
        "플레이스테이션": "gamecontroller.fill",
        "노래방": "gamecontroller.fill",
        "헬스": "gamecontroller.fill",
        "피트니스": "gamecontroller.fill",
        "pt": "gamecontroller.fill",
        "필라테스": "gamecontroller.fill",
        "요가": "gamecontroller.fill",

        // Entertainment - English
        "movie": "gamecontroller.fill",
        "netflix": "gamecontroller.fill",
        "youtube": "gamecontroller.fill",
        "disney": "gamecontroller.fill",
        "spotify": "gamecontroller.fill",
        "game": "gamecontroller.fill",
        "steam": "gamecontroller.fill",
        "playstation": "gamecontroller.fill",
        "xbox": "gamecontroller.fill",
        "nintendo": "gamecontroller.fill",
        "gym": "gamecontroller.fill",
        "fitness": "gamecontroller.fill",

        // Income - Korean
        "월급": "banknote.fill",
        "급여": "banknote.fill",
        "보너스": "banknote.fill",
        "상여금": "banknote.fill",
        "용돈": "plus.circle.fill",
        "부수입": "plus.circle.fill",
        "투자": "chart.line.uptrend.xyaxis",
        "배당": "chart.line.uptrend.xyaxis",
        "이자": "chart.line.uptrend.xyaxis",

        // Income - English
        "salary": "banknote.fill",
        "paycheck": "banknote.fill",
        "bonus": "banknote.fill",
        "income": "banknote.fill",
        "investment": "chart.line.uptrend.xyaxis",
        "dividend": "chart.line.uptrend.xyaxis",
        "interest": "chart.line.uptrend.xyaxis"
    ]

    // MARK: - User Pattern Storage

    /// Stores user-specific keyword patterns (learned from usage)
    private var userPatterns: [String: String] = [:] {
        didSet {
            saveUserPatterns()
        }
    }

    private let userPatternsKey = "SmartCategoryUserPatterns"

    // MARK: - Initialization

    func loadUserPatterns() {
        if let data = UserDefaults.standard.data(forKey: userPatternsKey),
           let patterns = try? JSONDecoder().decode([String: String].self, from: data) {
            userPatterns = patterns
        }
    }

    private func saveUserPatterns() {
        if let data = try? JSONEncoder().encode(userPatterns) {
            UserDefaults.standard.set(data, forKey: userPatternsKey)
        }
    }

    // MARK: - Category Suggestion

    /// Suggests a category based on the note text
    /// - Parameters:
    ///   - note: The transaction note
    ///   - categories: Available categories
    /// - Returns: Suggested category or nil if no match
    func suggestCategory(
        for note: String,
        from categories: [Category]
    ) -> Category? {
        let lowercasedNote = note.lowercased()

        // First, check user patterns (highest priority)
        for (keyword, icon) in userPatterns {
            if lowercasedNote.contains(keyword.lowercased()) {
                if let category = categories.first(where: { $0.icon == icon }) {
                    return category
                }
            }
        }

        // Then, check built-in keywords
        for (keyword, icon) in keywordToCategoryIcon {
            if lowercasedNote.contains(keyword.lowercased()) {
                if let category = categories.first(where: { $0.icon == icon }) {
                    return category
                }
            }
        }

        return nil
    }

    // MARK: - Learning

    /// Learn from user's category selection
    /// - Parameters:
    ///   - note: The transaction note
    ///   - category: The category the user selected
    func learnFromSelection(note: String, category: Category) {
        // Extract significant words from note (at least 2 characters)
        let words = note.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }

        // Only learn if we have meaningful words
        for word in words {
            // Don't override built-in keywords
            if keywordToCategoryIcon[word] == nil {
                userPatterns[word] = category.icon
            }
        }
    }

    /// Get all learned patterns (for debugging/settings)
    func getLearnedPatterns() -> [String: String] {
        return userPatterns
    }

    /// Clear all learned patterns
    func clearLearnedPatterns() {
        userPatterns = [:]
    }
}
