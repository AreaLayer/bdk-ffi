import XCTest
@testable import BitcoinDevKit

private let SIGNET_ELECTRUM_URL = "ssl://mempool.space:60602"

final class LiveElectrumClientTests: XCTestCase {
    func testSyncedBalance() throws {
        let descriptor = try Descriptor(
            descriptor: "wpkh(tprv8ZgxMBicQKsPf2qfrEygW6fdYseJDDrVnDv26PH5BHdvSuG6ecCbHqLVof9yZcMoM31z9ur3tTYbSnr1WBqbGX97CbXcmp5H6qeMpyvx35B/84h/1h/0h/0/*)",
            network: Network.signet
        )
        let wallet = try Wallet.newNoPersist(
            descriptor: descriptor,
            changeDescriptor: nil,
            network: .signet
        )
        let electrumClient: ElectrumClient = try ElectrumClient(url: SIGNET_ELECTRUM_URL)
        let fullScanRequest: FullScanRequest = wallet.startFullScan()
        let update = try electrumClient.fullScan(
            fullScanRequest: fullScanRequest,
            stopGap: 10,
            batchSize: 10,
            fetchPrevTxouts: false
        )
        try wallet.applyUpdate(update: update)
        let _ = try wallet.commit()
        let address = try wallet.revealNextAddress(keychain: KeychainKind.external).address.asString()

        XCTAssertGreaterThan(
            wallet.getBalance().total.toSat(),
            UInt64(0),
            "Wallet must have positive balance, please send funds to \(address)"
        )

        print("Transactions count: \(wallet.transactions().count)")
        let transactions = wallet.transactions().prefix(3)
        for tx in transactions {
            let sentAndReceived = wallet.sentAndReceived(tx: tx.transaction)
            print("Transaction: \(tx.transaction.txid())")
            print("Sent \(sentAndReceived.sent.toSat())")
            print("Received \(sentAndReceived.received.toSat())")
        }
    }
}
