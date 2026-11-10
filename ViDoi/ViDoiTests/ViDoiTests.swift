import XCTest
@testable import ViDoi

final class ViDoiTests: XCTestCase {
    func testCalculatorEvaluate() {
        XCTAssertEqual(AddTransactionView.evaluate(""), 0)
        XCTAssertEqual(AddTransactionView.evaluate("50000"), 50_000)
        XCTAssertEqual(AddTransactionView.evaluate("50000+25000"), 75_000)
        XCTAssertEqual(AddTransactionView.evaluate("100000-35000+10000"), 75_000)
    }

    func testBalanceCalculationWith60_40Ratio() {
        let store = AppStore(sync: LocalOnlySync())
        store.resetAll()
        store.ratioMe = 60 // Tôi chịu 60%, vợ/chồng chịu 40%
        let w = store.wallets[0].id
        let me = store.meID
        let partner = store.partner.id

        // Tôi trả 6.000.000, vợ/chồng trả 4.000.000 -> tổng 10.000.000 -> đã đúng 60/40
        store.add(Txn(kind: .expense, amount: 6_000_000, category: "Nhà cửa", date: Date(), walletID: w, userID: me, isShared: true))
        store.add(Txn(kind: .expense, amount: 4_000_000, category: "Chợ", date: Date(), walletID: w, userID: partner, isShared: true))
        XCTAssertEqual(store.balance().owe, 0)

        // Tôi trả thêm 1.000.000 chung -> tổng 11tr, phần tôi = 6,6tr, tôi đã trả 7tr -> người kia cần chuyển tôi 400.000
        store.add(Txn(kind: .expense, amount: 1_000_000, category: "Hóa đơn", date: Date(), walletID: w, userID: me, isShared: true))
        XCTAssertEqual(store.balance().owe, 400_000)
    }

    func testTransferUpdatesBothWallets() {
        let store = AppStore(sync: LocalOnlySync())
        store.resetAll()
        let w1 = store.wallets[0].id
        let w2 = store.wallets[1].id
        let b1 = store.wallets[0].balance
        let b2 = store.wallets[1].balance

        let t = Txn(kind: .transfer, amount: 500_000, category: "Chuyển khoản", date: Date(), walletID: w1, toWalletID: w2, userID: store.meID, isShared: true)
        store.add(t)
        XCTAssertEqual(store.wallets.first(where: { $0.id == w1 })?.balance, b1 - 500_000)
        XCTAssertEqual(store.wallets.first(where: { $0.id == w2 })?.balance, b2 + 500_000)

        // Xóa giao dịch chuyển ví phải hoàn lại đúng số dư cả 2 ví
        store.delete(t)
        XCTAssertEqual(store.wallets.first(where: { $0.id == w1 })?.balance, b1)
        XCTAssertEqual(store.wallets.first(where: { $0.id == w2 })?.balance, b2)
    }

    func testMergeTransactionsPreservesConcurrentItemsAndDeletions() {
        let u = UUID(), w = UUID()
        let t1 = Txn(kind: .expense, amount: 50_000, category: "Ăn uống", note: "A", date: Date(), walletID: w, userID: u, isShared: true)
        let t2 = Txn(kind: .expense, amount: 80_000, category: "Chợ", note: "B", date: Date(), walletID: w, userID: u, isShared: true)
        let tDeleted = Txn(kind: .expense, amount: 30_000, category: "Đi lại", note: "C", date: Date(), walletID: w, userID: u, isShared: true)

        let merged = AppStore.mergeTransactions(
            local: [t1, tDeleted],
            remote: [t2, tDeleted],
            deletedIDs: [tDeleted.id]
        )
        let ids = Set(merged.map(\.id))
        XCTAssertTrue(ids.contains(t1.id))
        XCTAssertTrue(ids.contains(t2.id))
        XCTAssertFalse(ids.contains(tDeleted.id))
    }

    func testTwoWayRatioConfirmationFlow() {
        let store = AppStore(sync: LocalOnlySync())
        store.resetAll()
        XCTAssertEqual(store.ratioMe, 50)

        store.requestRatioChange(newRatioMe: 65)
        // Chưa đổi ngay khi chưa xác nhận
        XCTAssertEqual(store.ratioMe, 50)
        XCTAssertEqual(store.pendingRatioForMe, 65)

        store.approvePendingRatio()
        XCTAssertEqual(store.ratioMe, 65)
        XCTAssertNil(store.pendingRatio)
    }
}
