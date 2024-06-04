import XCTest
@testable import BitcoinDevKit

private let SIGNET_ESPLORA_URL = "http://signet.bitcoindevkit.net"
private let TESTNET_ESPLORA_URL = "https://esplora.testnet.kuutamo.cloud"

final class LiveWalletTests: XCTestCase {
    var dbFilePath: URL!

    override func setUpWithError() throws {
        super.setUp()
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let uniqueDbFileName = "bdk_persistence_\(UUID().uuidString).sqlite"
        dbFilePath = documentDirectory.appendingPathComponent(uniqueDbFileName)

        if fileManager.fileExists(atPath: dbFilePath.path) {
            try fileManager.removeItem(at: dbFilePath)
        }
    }

    override func tearDownWithError() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: dbFilePath.path) {
            try fileManager.removeItem(at: dbFilePath)
        }
    }

    func testSyncedBalance() throws {
        let descriptor = try Descriptor(
            descriptor: "wpkh(tprv8ZgxMBicQKsPf2qfrEygW6fdYseJDDrVnDv26PH5BHdvSuG6ecCbHqLVof9yZcMoM31z9ur3tTYbSnr1WBqbGX97CbXcmp5H6qeMpyvx35B/84h/1h/0h/0/*)",
            network: Network.signet
        )
        let wallet = try Wallet(
            descriptor: descriptor,
            changeDescriptor: nil,
            persistenceBackendPath: dbFilePath.path,
            network: .signet
        )
        let esploraClient = EsploraClient(url: SIGNET_ESPLORA_URL)
        let fullScanRequest: FullScanRequest = wallet.startFullScan()
        let update = try esploraClient.fullScan(
            fullScanRequest: fullScanRequest,
            stopGap: 10,
            parallelRequests: 1
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
    
    func testBroadcastTransaction() throws {
        let descriptor = try Descriptor(
            descriptor: "wpkh(tprv8ZgxMBicQKsPf2qfrEygW6fdYseJDDrVnDv26PH5BHdvSuG6ecCbHqLVof9yZcMoM31z9ur3tTYbSnr1WBqbGX97CbXcmp5H6qeMpyvx35B/84h/1h/0h/0/*)",
            network: Network.signet
        )
        let wallet = try Wallet(
            descriptor: descriptor,
            changeDescriptor: nil,
            persistenceBackendPath: dbFilePath.path,
            network: .signet
        )
        let esploraClient = EsploraClient(url: SIGNET_ESPLORA_URL)
        let fullScanRequest: FullScanRequest = wallet.startFullScan()
        let update = try esploraClient.fullScan(
            fullScanRequest: fullScanRequest,
            stopGap: 10,
            parallelRequests: 1
        )
        try wallet.applyUpdate(update: update)
        let _ = try wallet.commit()
        let address = try wallet.revealNextAddress(keychain: KeychainKind.external).address.asString()
        
        XCTAssertGreaterThan(
            wallet.getBalance().total.toSat(),
            UInt64(0),
            "Wallet must have positive balance, please send funds to \(address)"
        )

        print("Balance: \(wallet.getBalance().total)")

        let recipient: Address = try Address(address: "tb1qrnfslnrve9uncz9pzpvf83k3ukz22ljgees989", network: .signet)
        let psbt: Psbt = try
            TxBuilder()
            .addRecipient(script: recipient.scriptPubkey(), amount: Amount.fromSat(fromSat: 4200))
                .feeRate(feeRate: FeeRate.fromSatPerVb(satPerVb: 2))
                .finish(wallet: wallet)

        print(psbt.serialize())
        XCTAssertTrue(psbt.serialize().hasPrefix("cHNi"), "PSBT should start with cHNI")

        let walletDidSign: Bool = try wallet.sign(psbt: psbt)
        XCTAssertTrue(walletDidSign, "Wallet did not sign transaction")

        let tx: Transaction = try! psbt.extractTx()
        print(tx.txid())
        let fee: UInt64 = try wallet.calculateFee(tx: tx)
        print("Transaction Fee: \(fee)")
        let feeRate: FeeRate = try wallet.calculateFeeRate(tx: tx)
        print("Transaction Fee Rate: \(feeRate.toSatPerVbCeil()) sat/vB")

        try esploraClient.broadcast(transaction: tx)
    }
}
