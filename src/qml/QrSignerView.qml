import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// The QR signer's app: add an air-gapped wallet's accounts from its account code, and choose which
// ones Logos apps may use. A .rep SLOT answers a pending reply, so calls go through logos.watch.
Item {
    id: root
    objectName: "qrSignerRoot"
    anchors.fill: parent

    Rectangle { anchors.fill: parent; color: Theme.palette.background }

    readonly property var backend: logos.module("qr_signer_ui")

    // Writable, fed by the signal: a binding with a function call would latch false at creation.
    property bool ready: false
    Connections {
        target: logos
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName === "qr_signer_ui") root.ready = isReady && root.backend !== null
        }
    }

    function j(t, fb) { try { return JSON.parse(t && t.length ? t : fb) } catch (e) { return JSON.parse(fb) } }
    readonly property var profiles: ready ? j(backend.profilesJson, "[]") : []
    readonly property var accounts: ready ? j(backend.accountsJson, "[]") : []
    readonly property var scanning: ready ? j(backend.scanJson, "{}") : ({})
    readonly property bool waiting: scanning.state === "scanning"
    // Empty: the wallet's code says which wallet it is.
    property string profile: ""

    function familyWords(f) {
        return f === "evm" ? "EVM" : f === "bitcoin" ? "Bitcoin, native segwit" : "Bitcoin, taproot"
    }

    function accountName(a) {
        var test = a.family !== "evm" && (a.path || "").indexOf("/1'/") >= 0
        return (a.label || root.familyWords(a.family)) + (test ? " (test)" : "")
    }

    function scanLine() {
        if (root.waiting)
            return "Hold the wallet's account code up to the camera. On a Keycard Shell: Connect software wallet."
        if (root.scanning.state === "done") {
            var n = (root.scanning.accounts || []).length
            return "Added " + n + (n === 1 ? " account." : " accounts.")
        }
        if (root.scanning.state === "failed") return "Not added: " + (root.scanning.error || "")
        return ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.medium
        spacing: Theme.spacing.small

        LogosText { text: "QR Wallets"; font.pixelSize: 22 }

        LogosText {
            objectName: "qrNote"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Air-gapped wallets that sign over QR codes, such as the Keycard Shell, Keystone, "
                  + "Passport and Jade. Their keys never leave them: each request is shown here as a "
                  + "code for the wallet to scan, and its answer is read back through the camera."
        }

        // ── adding a wallet's accounts ───────────────────────────────────────────
        LogosText { text: "Add a QR wallet"; font.bold: true }
        LogosText { text: "Which wallet"; color: Theme.palette.textSecondary }
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            ButtonGroup { id: walletGroup }
            LogosRadioButton {
                objectName: "walletFromCode"
                ButtonGroup.group: walletGroup
                text: "As its code says"
                checked: true
                onClicked: root.profile = ""
            }
            Repeater {
                model: root.profiles
                delegate: LogosRadioButton {
                    objectName: "wallet_" + modelData.name
                    ButtonGroup.group: walletGroup
                    text: modelData.label
                    onClicked: root.profile = modelData.name
                }
            }
        }
        RowLayout {
            spacing: Theme.spacing.small
            LogosCheckbox { id: evmBox; objectName: "scanEvm"; text: "EVM"; checked: true }
            LogosCheckbox { id: segwitBox; objectName: "scanSegwit"; text: "Bitcoin, native segwit" }
            LogosCheckbox { id: taprootBox; objectName: "scanTaproot"; text: "Bitcoin, taproot" }
        }
        LogosTextField {
            id: labelField
            objectName: "scanLabel"
            Layout.fillWidth: true
            placeholderText: "Name (optional)"
        }
        LogosText {
            objectName: "scanNote"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "The accounts come from the code the wallet shows, on the network it is set to. "
                  + "Only public keys are kept, and the camera is asked for in the name of Logos QR."
        }
        LogosButton {
            objectName: "scanButton"
            text: "Read the wallet's code"
            enabled: root.ready && !root.waiting
                     && (evmBox.checked || segwitBox.checked || taprootBox.checked)
            onClicked: {
                var families = []
                if (evmBox.checked) families.push("evm")
                if (segwitBox.checked) families.push("bitcoin")
                if (taprootBox.checked) families.push("bitcoin_taproot")
                logos.watch(root.backend.scan(JSON.stringify(families), root.profile, labelField.text),
                            function (started) {})
            }
        }
        LogosText {
            objectName: "scanLine"
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: root.scanning.state === "failed" ? Theme.palette.error : Theme.palette.text
            text: root.scanLine()
        }

        // ── the accounts offered ─────────────────────────────────────────────────
        LogosText { text: "Offered to apps"; font.bold: true }
        LogosText {
            objectName: "noAccounts"
            visible: root.ready && root.accounts.length === 0
            color: Theme.palette.textSecondary
            text: "No account offered yet."
        }
        Repeater {
            id: accountRepeater
            objectName: "accountRepeater"
            model: root.accounts
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.small
                LogosText {
                    objectName: "accountLine_" + index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.accountName(modelData) + " — " + (modelData.address || modelData.path || modelData.id)
                }
                LogosButton {
                    objectName: "removeAccount_" + index
                    text: "Remove"
                    onClicked: logos.watch(root.backend.removeAccount(modelData.id), function (gone) {})
                }
            }
        }

        LogosText {
            objectName: "lastError"
            Layout.fillWidth: true
            visible: root.ready && root.backend.lastError !== ""
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: Theme.palette.error
            text: root.ready ? root.backend.lastError : ""
        }

        Item { Layout.fillHeight: true }
    }
}
