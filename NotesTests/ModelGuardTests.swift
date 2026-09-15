import XCTest
@testable import Notes

final class ModelGuardTests: XCTestCase {
    func testSharesWordsCatchesInventions() {
        let source = "milk eggs and call the dentist tuesday"
        XCTAssertTrue(ModelGuard.sharesWords("Call the dentist", with: source))
        XCTAssertTrue(ModelGuard.sharesWords("MILK", with: source))
        XCTAssertFalse(ModelGuard.sharesWords("Buy bread", with: source))
        // Short words carry nothing, so "a" and "to" never fail a check.
        XCTAssertTrue(ModelGuard.sharesWords("a to", with: source))
        XCTAssertTrue(ModelGuard.sharesWords("Café", with: "cafe at noon"))
        // Stop words carry nothing either.
        XCTAssertTrue(ModelGuard.sharesWords("the dentist and the milk", with: source))
        XCTAssertFalse(ModelGuard.words("when is the dentist").contains("the"))
    }

    func testKeptIsTheShareOfSourceWordsThatSurvive() {
        XCTAssertEqual(ModelGuard.kept(of: "milk eggs bread", in: "Milk and eggs"), 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(ModelGuard.kept(of: "", in: "anything"), 1)
    }

    func testLengthCloseAllowsFixesNotRewrites() {
        XCTAssertTrue(ModelGuard.lengthClose("call teh dentist", "Call the dentist."))
        XCTAssertTrue(ModelGuard.lengthClose("milk eggs bread tea", "Milk, eggs, bread, tea."))
        XCTAssertFalse(ModelGuard.lengthClose("milk", "Remember to buy some milk today"))
        XCTAssertTrue(ModelGuard.lengthClose("", ""))
        XCTAssertFalse(ModelGuard.lengthClose("", "new"))
    }
}

extension ModelGuardTests {
    func testTidyKeepsCleaningNotRewriting() {
        let others = ["This week", "i recieved the parcel , its fine"]
        XCTAssertTrue(ModelGuard.tidyKeeps("call teh dentist", "Call the dentist.", others: others))
        XCTAssertTrue(ModelGuard.tidyKeeps("milk eggs bread", "Milk, eggs, bread", others: others))
        XCTAssertTrue(ModelGuard.tidyKeeps("", "", others: others))
        XCTAssertFalse(ModelGuard.tidyKeeps("", "New line", others: others))
        XCTAssertFalse(ModelGuard.tidyKeeps("call teh dentist", "", others: others))
        // Rewritten: the words are gone.
        XCTAssertFalse(ModelGuard.tidyKeeps("call teh dentist", "Ring the tooth doctor", others: others))
        // Grown: more than half again.
        XCTAssertFalse(ModelGuard.tidyKeeps("milk", "Remember to buy some milk today", others: others))
        // Two lines run together: the neighbour's words came in.
        XCTAssertFalse(ModelGuard.tidyKeeps(
            "call teh dentist", "Call the dentist. I received the parcel, it's fine.", others: others))
    }

    func testAbsorbsNeedsTwoForeignWords() {
        XCTAssertTrue(ModelGuard.absorbs("Call the dentist, parcel fine", own: "call teh dentist", from: ["i recieved the parcel , its fine"]))
        XCTAssertFalse(ModelGuard.absorbs("Call the dentist about the parcel", own: "call teh dentist", from: ["i recieved the parcel , its fine"]))
        XCTAssertFalse(ModelGuard.absorbs("Milk, eggs, bread", own: "milk eggs bread", from: ["Groceries", "eggs and milk"]))
    }
}

extension ModelGuardTests {
    func testTidyKeepsAllowsASpellingFix() {
        // The corrected word is not the word that was there, so counting
        // exact survivors read a two-word line as half destroyed.
        XCTAssertTrue(ModelGuard.tidyKeeps("buy tomatos", "Buy tomatoes", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("wenesday meeting", "Wednesday meeting", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("i recieved it", "I received it", others: []))
        // A different word is still a rewrite.
        XCTAssertFalse(ModelGuard.tidyKeeps("buy tomatos", "Buy potatoes and bread", others: []))
    }

    func testNearIsOneEditForShortWordsAndTwoForLong() {
        XCTAssertTrue(ModelGuard.near("tomatos", "tomatoes"))
        XCTAssertTrue(ModelGuard.near("teh", "the"))
        XCTAssertTrue(ModelGuard.near("hotel", "hotels"))
        XCTAssertFalse(ModelGuard.near("cat", "dog"))
        XCTAssertFalse(ModelGuard.near("milk", "bread"))
    }

    func testGroundedAllowsAnInflectionButNotAnInvention() {
        let note = "Japan trip\nHotels: one near the station, one by the park"
        XCTAssertTrue(ModelGuard.grounded("which hotel", in: note))
        XCTAssertTrue(ModelGuard.grounded("the stations", in: note))
        XCTAssertFalse(ModelGuard.grounded("book the flights", in: note))
        // Nothing but small words says nothing, and must not pass.
        XCTAssertFalse(ModelGuard.grounded("do it", in: note))
        XCTAssertFalse(ModelGuard.grounded("", in: note))
    }

    // MARK: Scripts without word spaces
    //
    // Chinese, Japanese and Thai write without spaces, so the tokeniser
    // used to see a whole line as one word and every guard collapsed the
    // moment the model changed anything — including adding the punctuation
    // it is asked for. These tests assert OUTCOMES, never token lists: the
    // segmentation is ours, but pinning its exact shape would make every
    // internal improvement a test failure.

    func testCleanupSurvivesPunctuationInChinese() {
        let said = "买牛奶和鸡蛋然后给牙医打电话"
        let cleaned = "买牛奶和鸡蛋，然后给牙医打电话。"
        // OnDevice accepts a dictation cleanup at 0.5; punctuation alone
        // must leave a wide margin, not scrape by.
        XCTAssertTrue(ModelGuard.kept(of: said, in: cleaned) >= 0.9)
        XCTAssertTrue(ModelGuard.grounded(cleaned, in: said))
    }

    func testCleanupSurvivesPunctuationInJapanese() {
        let said = "牛乳と卵を買って歯医者に電話する"
        let cleaned = "牛乳と卵を買って、歯医者に電話する。"
        XCTAssertTrue(ModelGuard.kept(of: said, in: cleaned) >= 0.9)
        XCTAssertTrue(ModelGuard.grounded(cleaned, in: said))
    }

    func testCleanupSurvivesASpaceInThai() {
        let said = "ซื้อนมและไข่แล้วโทรหาหมอฟัน"
        let cleaned = "ซื้อนมและไข่ แล้วโทรหาหมอฟัน"
        XCTAssertTrue(ModelGuard.kept(of: said, in: cleaned) >= 0.9)
    }

    func testKoreanIsUntouched() {
        // Korean writes with spaces and already worked; it must not be
        // routed through anything new.
        let said = "우유와 계란을 사고 치과에 전화하기"
        let cleaned = "우유와 계란을 사고, 치과에 전화하기."
        XCTAssertEqual(ModelGuard.kept(of: said, in: cleaned), 1.0)
        XCTAssertTrue(ModelGuard.tidyKeeps(said, cleaned, others: []))
    }

    func testAPunctuationOnlyTidyIsTheSameLine() {
        XCTAssertTrue(ModelGuard.tidyKeeps("买米面油", "买米、面、油", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("买牛奶和鸡蛋", "买牛奶和鸡蛋。", others: []))
    }

    func testInventedChineseIsRefused() {
        let note = "去日本旅行\n预算三千美元\n十月十五号出发\n住在车站附近的酒店"
        // Five thousand for three thousand, November for October: numbers
        // and dates the note does not say, refused.
        XCTAssertFalse(ModelGuard.grounded("预算五千美元", in: note))
        XCTAssertFalse(ModelGuard.grounded("十一月去日本", in: note))
    }

    func testARewrittenJapaneseLineIsRefused() {
        XCTAssertFalse(ModelGuard.tidyKeeps("牛乳と卵を買って歯医者に電話する",
                                            "スーパーで新しい食材を注文する", others: []))
    }

    func testASingleCharacterItemIsRealAndAnInventedOneIsNot() {
        // 米 (rice) is in the note even though the note writes it with no
        // space around it; 猫 (cat) is not in the note at all. One-character
        // items are ordinary on a Chinese list, and an empty word set must
        // never pass the subset check by being empty.
        XCTAssertTrue(ModelGuard.sharesWords("米", with: "买米和油"))
        XCTAssertFalse(ModelGuard.sharesWords("猫", with: "买米和油"))
        XCTAssertTrue(ModelGuard.grounded("米、油", in: "买米和油"))
    }

    func testChineseFitsTheWordLimits() {
        // OnDevice refuses a title over eight words; a ten-character
        // Chinese title is about five words, not one and not ten.
        XCTAssertTrue((2...8).contains(ModelGuard.wordCount("十月去日本的旅行计划")))
        XCTAssertEqual(ModelGuard.wordCount("买iPhone手机"), 3)
        XCTAssertTrue(ModelGuard.lengthClose("买牛奶和鸡蛋然后给牙医打电话",
                                             "买牛奶和鸡蛋，然后给牙医打电话。"))
    }

    func testTheKnownHolesStayKnown() {
        // These pass DELIBERATELY, and each is a hole English has too.
        // If a change makes one fail, that is an improvement to make on
        // purpose, not to discover in CI.
        //
        // Negation survives the tidy guard: "don't call the dentist" keeps
        // every word of "call the dentist", in any language.
        XCTAssertTrue(ModelGuard.tidyKeeps("给牙医打电话", "不用给牙医打电话。", others: []))
        // A short dense line can be rewritten within the 0.6 ratio:
        // "buy eggs" to "buy bread" shares its verb, and two characters of
        // three. Better than before the fix (which accepted more), not solved.
        XCTAssertTrue(ModelGuard.tidyKeeps("卵を買う", "パンを買う", others: []))
        // Recombination passes grounded — "buy milk for the dentist" out of
        // a note that says call the dentist and buy milk — though the
        // stricter subset check does catch it, because the joined phrase
        // contains a character pair the note never wrote.
        let note = "给牙医打电话\n买牛奶"
        XCTAssertTrue(ModelGuard.grounded("给牙医买牛奶", in: note))
        XCTAssertFalse(ModelGuard.sharesWords("给牙医买牛奶", with: note))
        // The swapped day that used to be pinned here is closed: numbers
        // and days are matched exactly now, so 周三 for 周二 is refused and
        // so is 3800 for 3500. What is left of the hole is the day and
        // month words that are also ordinary English. "may", "march" and
        // "august" are deliberately not treated as dates — refusing "may
        // need a hotel" for naming a month is worse than this — so those
        // three alone still ride the ratio when the rest of a long line
        // is unchanged.
        XCTAssertTrue(ModelGuard.grounded("meeting in may about the parcel and the dentist",
                                          in: "meeting in march about the parcel and the dentist"))
    }
}

// MARK: Numbers and days are matched exactly
//
// A ratio can absorb one changed token when the rest of the line is
// unchanged, and the spelling allowance reads 3800 as one edit from 3500 —
// a typo. Both are right about words and wrong about figures: a number or a
// day is the same one or a different one, and there is nothing in between.
// So they are checked apart from the ratios, and a figure the source does
// not say refuses the whole candidate.

extension ModelGuardTests {
    func testAChangedAmountIsRefused() {
        XCTAssertFalse(ModelGuard.grounded("pay 3800", in: "pay 3500"))
        XCTAssertFalse(ModelGuard.tidyKeeps("rent 3500 due friday", "Rent 3800, due Friday.", others: []))
        XCTAssertFalse(ModelGuard.sharesWords("pay 3800", with: "pay 3500"))
    }

    func testANumberTooShortToBeAWordIsStillChecked() {
        // The three-letter floor in `words` dropped "16" before it reached
        // any guard, so a model answer that changed it was checked against
        // nothing at all.
        XCTAssertFalse(ModelGuard.grounded("bus 16 at noon", in: "bus 18 at noon"))
        XCTAssertFalse(ModelGuard.sharesWords("bus 16", with: "bus 18"))
        XCTAssertFalse(ModelGuard.tidyKeeps("take bus 18", "Take bus 16.", others: []))
    }

    func testAChangedDayIsRefused() {
        XCTAssertFalse(ModelGuard.grounded("wednesday afternoon at three",
                                           in: "tuesday afternoon at three"))
        XCTAssertFalse(ModelGuard.tidyKeeps("dentist on tuesday", "Dentist on Wednesday.", others: []))
        // The Chinese half of the same hole: 周三 for 周二 kept three
        // quarters of the pairs, which cleared the 0.75 ratio exactly.
        XCTAssertFalse(ModelGuard.grounded("周三下午三点看牙医", in: "周二下午三点看牙医"))
    }

    func testAChangedAmountInAScriptWithoutSpacesIsRefused() {
        XCTAssertFalse(ModelGuard.tidyKeeps("房租3500块", "房租3800块", others: []))
        XCTAssertFalse(ModelGuard.grounded("预算五千美元", in: "预算三千美元"))
        XCTAssertFalse(ModelGuard.grounded("十一月十五号出发", in: "十月十五号出发"))
    }

    func testNothingElseWasCalibratedLooserToCompensate() {
        // The figures that did not change must still pass everything they
        // passed before, in both kinds of script.
        XCTAssertTrue(ModelGuard.tidyKeeps("rent 3500 due friday", "Rent 3500, due Friday.", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("buy 2 tomatos", "Buy 2 tomatoes", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("房租3500块", "房租3500块。", others: []))
        XCTAssertTrue(ModelGuard.grounded("3500 rent", in: "rent 3500 due friday"))
        XCTAssertTrue(ModelGuard.grounded("周二下午看牙医", in: "周二下午三点看牙医"))
        XCTAssertTrue(ModelGuard.sharesWords("bus 18", with: "take bus 18 at noon"))
        // A thousands separator is the same amount written out.
        XCTAssertTrue(ModelGuard.tidyKeeps("rent 3500", "Rent: 3,500", others: []))
    }

    func testAShortNumberIsAWordLikeAnyOther() {
        // The three-letter floor is about letters: "at" and "to" say
        // nothing. A number always says something, however short — a bus,
        // a flat, a time, an amount — and a ratio that cannot see one
        // reads two different bus numbers as the same line.
        XCTAssertTrue(ModelGuard.words("take bus 16").contains("16"))
        XCTAssertTrue(ModelGuard.kept(of: "bus 16", in: "bus 18") < 1)
        XCTAssertEqual(ModelGuard.kept(of: "bus 16", in: "the 16 bus"), 1.0)
    }

    func testAYearWrittenInHanIsOneNumber() {
        // A run of Han numerals is one figure, so 二〇 is not a piece of
        // 二〇二五 that a candidate can be grounded in — the same way 16 is
        // not a piece of 1600.
        XCTAssertFalse(ModelGuard.grounded("二〇年去日本", in: "二〇二五年去日本"))
        XCTAssertTrue(ModelGuard.grounded("二〇二五年去日本", in: "二〇二五年去日本"))
        XCTAssertFalse(ModelGuard.grounded("flat 16", in: "flat 1600"))
    }

    func testADayMisspeltCanStillBePutRight() {
        // The one correction exactness must not take away: a misspelling
        // that is not itself a day becoming the day it meant. Changing one
        // real day into another is the thing being refused, not this.
        XCTAssertTrue(ModelGuard.tidyKeeps("wenesday meeting", "Wednesday meeting", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("see you tuesady", "See you Tuesday.", others: []))
        // An invented time is not a correction of anything.
        XCTAssertFalse(ModelGuard.tidyKeeps("call teh dentist", "Call the dentist at 3.", others: []))
    }
}
