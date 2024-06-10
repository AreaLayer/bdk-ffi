package org.bitcoindevkit

import kotlin.test.Test

private const val SIGNET_ESPLORA_URL = "http://signet.bitcoindevkit.net"
private const val TESTNET_ESPLORA_URL = "https://esplora.testnet.kuutamo.cloud"

class LiveMemoryWalletTest {

    @Test
    fun testSyncedBalance() {
        val descriptor: Descriptor = Descriptor(
            "wpkh(tprv8ZgxMBicQKsPf2qfrEygW6fdYseJDDrVnDv26PH5BHdvSuG6ecCbHqLVof9yZcMoM31z9ur3tTYbSnr1WBqbGX97CbXcmp5H6qeMpyvx35B/84h/1h/0h/0/*)",
            Network.SIGNET
        )
        val wallet: Wallet = Wallet.newNoPersist(descriptor, null, Network.SIGNET)
        val esploraClient: EsploraClient = EsploraClient(SIGNET_ESPLORA_URL)
        val fullScanRequest: FullScanRequest = wallet.startFullScan()
        val update = esploraClient.fullScan(fullScanRequest, 10uL, 1uL)
        wallet.applyUpdate(update)
        wallet.commit()
        println("Balance: ${wallet.getBalance().total.toSat()}")

        assert(wallet.getBalance().total.toSat() > 0uL) {
            "Wallet balance must be greater than 0! Please send funds to ${wallet.revealNextAddress(KeychainKind.EXTERNAL).address} and try again."
        }

        println("Transactions count: ${wallet.transactions().count()}")
        val transactions = wallet.transactions().take(3)
        for (tx in transactions) {
            val sentAndReceived = wallet.sentAndReceived(tx.transaction)
            println("Transaction: ${tx.transaction.txid()}")
            println("Sent ${sentAndReceived.sent.toSat()}")
            println("Received ${sentAndReceived.received.toSat()}")
        }
    }

    @Test
    fun testScriptInspector() {
        val descriptor: Descriptor = Descriptor(
            "wpkh(tprv8ZgxMBicQKsPf2qfrEygW6fdYseJDDrVnDv26PH5BHdvSuG6ecCbHqLVof9yZcMoM31z9ur3tTYbSnr1WBqbGX97CbXcmp5H6qeMpyvx35B/84h/1h/0h/0/*)",
            Network.SIGNET
        )
        val changeDescriptor: Descriptor = Descriptor(
            "wpkh(tprv8ZgxMBicQKsPf2qfrEygW6fdYseJDDrVnDv26PH5BHdvSuG6ecCbHqLVof9yZcMoM31z9ur3tTYbSnr1WBqbGX97CbXcmp5H6qeMpyvx35B/84h/1h/0h/1/*)",
            Network.SIGNET
        )
        val wallet: Wallet = Wallet.newNoPersist(descriptor, changeDescriptor, Network.SIGNET)
        val esploraClient: EsploraClient = EsploraClient(SIGNET_ESPLORA_URL)

        val scriptInspector: FullScriptInspector = FullScriptInspector()
        val fullScanRequest: FullScanRequest = wallet.startFullScan().inspectSpksForAllKeychains(scriptInspector)
        val update = esploraClient.fullScan(fullScanRequest, 21uL, 1uL)

        wallet.applyUpdate(update)
        wallet.commit()
        println("Balance: ${wallet.getBalance().total.toSat()}")

        assert(wallet.getBalance().total.toSat() > 0uL) {
            "Wallet balance must be greater than 0! Please send funds to ${wallet.revealNextAddress(KeychainKind.EXTERNAL).address} and try again."
        }

    }

}

class FullScriptInspector: FullScanScriptInspector {
    override fun inspect(keychain: KeychainKind, index: UInt, script: Script){
        println("Inspecting index $index for keychain $keychain")
    }
}