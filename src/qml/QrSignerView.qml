import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// The QR signer's app: air-gapped wallets that sign over QR codes, one card a wallet, its accounts
// added from the code it shows. A .rep SLOT answers a pending reply, so calls go through logos.watch.
Item {
    id: root
    objectName: "qrSignerRoot"
    anchors.fill: parent

    Rectangle { anchors.fill: parent; color: Theme.palette.background }

    readonly property var backend: logos.module("qr_signer_ui")

    // Writable, fed by the signal: a binding with a function call would latch false at creation.
    property bool ready: false
    Component.onCompleted: ready = backend !== null && logos.isViewModuleReady("qr_signer_ui")
    Connections {
        target: logos
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName === "qr_signer_ui") root.ready = isReady && root.backend !== null
        }
    }

    function j(t, fb) { try { return JSON.parse(t && t.length ? t : fb) } catch (e) { return JSON.parse(fb) } }
    readonly property var profiles: ready ? j(backend.profilesJson, "[]") : []
    readonly property var wallets: ready ? j(backend.walletsJson, "[]") : []
    readonly property var scanning: ready ? j(backend.scanJson, "{}") : ({})
    // How the camera reads the code, while this app draws the scan: no picture, only whether a code
    // is in view and the parts read.
    readonly property var scanView: ready ? j(backend.scanViewJson, "{}") : ({})
    readonly property bool working: scanning.state === "scanning"
    property string selectedFingerprint: ""
    readonly property var wallet: wallets.find(function(w) { return w.fingerprint === root.selectedFingerprint }) || null

    function walletName(w) {
        if (!w) return "QR wallet"
        return (w.label || "QR wallet") + (w.fingerprint ? " · " + w.fingerprint : "")
    }
    function familyWords(f) {
        return f === "evm" ? "Ethereum" : f === "bitcoin" ? "Bitcoin · Native SegWit" : "Bitcoin · Taproot"
    }
    function shortKey(k) { return k ? k.slice(0, 8) + "…" + k.slice(-6) : "" }
    function count(n) { return n + (n === 1 ? " account" : " accounts") }
    function openAdd(w) {
        root.selectedFingerprint = w ? w.fingerprint : ""
        addSheet.open()
    }
    // What the signer manager says of a wallet, once it says: with no way in, its accounts can't be
    // opened after a restart.
    function noWayIn(w) { return !!w && w.wayIn === false }
    function canGiveKey(w) { return !!w && w.profile === "keycard_shell" && w.unlockKey === false }
    function noWayInWords(w) {
        if (root.canGiveKey(w))
            return "No way in yet: until you give its unlock key, or set a password for it in the Signer app, its accounts can't be opened after a restart."
        if (w && w.unlockKey === false)
            return "No way in yet: until you set a password for it in the Signer app, its accounts can't be opened after a restart. Wallets of this kind give no unlock key."
        return "No way in yet: until you set one in the Signer app, its accounts can't be opened after a restart."
    }
    function openGiveKey(w) {
        root.selectedFingerprint = w.fingerprint
        keySheet.open()
    }

    LogosScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: Theme.spacing.medium
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Theme.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                LogosText { text: "QR wallets"; font.pixelSize: 22 }
                LogosInfoButton {
                    objectName: "qrWalletInfo"
                    title: "Wallets that sign over QR codes"
                    Accessible.name: "Help: Wallets that sign over QR codes"
                    text: "Air-gapped wallets such as the Keycard Shell, Keystone, Passport and Jade never connect to "
                          + "this computer. Each request is shown here as animated QR codes for the wallet to scan. "
                          + "You check and confirm it on the wallet, then press Scan the answer in the Logos QR "
                          + "window (or Enter in a terminal) and hold the wallet's answer up to the camera: "
                          + "the camera stays off until then. "
                          + "The camera belongs to Logos QR, and macOS asks for it once, in that name. "
                          + "Only public keys are kept on this computer; spending still needs the wallet."
                }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "addWallet"
                    text: "Add a QR wallet…"
                    enabled: root.ready && !root.working
                    onClicked: root.openAdd(null)
                }
                LogosButton { text: "Refresh"; enabled: root.ready && !root.working; onClicked: root.backend.refresh() }
            }
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                text: "Add a wallet from the account code it shows. Your keys stay on the wallet."
            }
            LogosText {
                objectName: "noWallets"
                visible: root.ready && root.wallets.length === 0
                text: "Add a QR wallet to see its accounts here."
            }

            Repeater {
                objectName: "walletRepeater"
                model: root.wallets
                delegate: Frame {
                    id: group
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    padding: Theme.spacing.medium
                    background: Rectangle { radius: 6; color: Theme.palette.backgroundMuted }
                    contentItem: ColumnLayout {
                        spacing: Theme.spacing.small
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                LogosText {
                                    objectName: "walletName_" + group.index
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    font.bold: true
                                    text: root.walletName(group.modelData)
                                }
                                LogosText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: Theme.palette.textSecondary
                                    text: "Signs over QR codes · " + root.count(group.modelData.accounts.length)
                                }
                            }
                            LogosButton {
                                objectName: "addAccounts_" + group.index
                                text: "Add accounts"
                                enabled: !root.working
                                onClicked: root.openAdd(group.modelData)
                            }
                            LogosButton {
                                objectName: "manageWallet_" + group.index
                                text: "Manage…"
                                enabled: !root.working
                                onClicked: { root.selectedFingerprint = group.modelData.fingerprint; manageSheet.open() }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.noWayIn(group.modelData)
                            LogosText {
                                objectName: "noWayIn_" + group.index
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                wrapMode: Text.WordWrap
                                color: Theme.palette.error
                                text: root.noWayInWords(group.modelData)
                            }
                            LogosButton {
                                objectName: "giveKey_" + group.index
                                visible: root.canGiveKey(group.modelData)
                                text: "Give its unlock key…"
                                enabled: !root.working
                                onClicked: root.openGiveKey(group.modelData)
                            }
                        }
                        LogosText {
                            visible: group.modelData.accounts.length === 0
                            text: "No accounts yet."
                            color: Theme.palette.textSecondary
                        }
                        Repeater {
                            objectName: "accountRepeater_" + group.index
                            model: group.modelData.accounts
                            delegate: RowLayout {
                                required property var modelData
                                required property int index
                                readonly property bool evm: modelData.family === "evm"
                                readonly property string key: evm ? (modelData.address || "") : (modelData.xpub || "")
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    LogosText {
                                        objectName: "accountLabel_" + group.index + "_" + index
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                        text: modelData.label || root.familyWords(modelData.family)
                                    }
                                    LogosText {
                                        objectName: "accountPath_" + group.index + "_" + index
                                        textFormat: Text.PlainText
                                        color: Theme.palette.textSecondary
                                        text: "Derivation path: " + (modelData.path || "Unavailable")
                                    }
                                    RowLayout {
                                        LogosText { color: Theme.palette.textSecondary; text: evm ? "Address:" : "Account key:" }
                                        LogosText {
                                            objectName: "accountLine_" + group.index + "_" + index
                                            textFormat: Text.PlainText
                                            color: Theme.palette.textSecondary
                                            text: key ? root.shortKey(key) : "Unavailable"
                                        }
                                        LogosCopyButton {
                                            objectName: "accountCopy_" + group.index + "_" + index
                                            visible: !!key
                                            value: key
                                        }
                                    }
                                }
                                LogosText {
                                    color: Theme.palette.textSecondary
                                    text: root.familyWords(modelData.family) + (modelData.chain === "test" ? " · Test" : "")
                                }
                            }
                        }
                    }
                }
            }

            LogosText {
                objectName: "lastError"
                Layout.fillWidth: true
                visible: root.ready && !!root.backend.lastError
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: Theme.palette.error
                text: root.ready ? root.backend.lastError : ""
            }
        }
    }

    // ── adding a wallet's accounts ───────────────────────────────────────────
    LogosDialog {
        id: addSheet
        objectName: "addWalletDialog"
        title: root.wallet ? "Add accounts · " + root.walletName(root.wallet) : "Add a QR wallet"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 580)
        closePolicy: root.working || submitting ? Popup.NoAutoClose : Popup.CloseOnEscape
        property bool submitting: false
        // Whether this opening started a scan, so an earlier one's outcome isn't shown.
        property bool started: false
        onOpened: {
            submitting = false; started = false
            scanEvm.checked = true; scanSegwit.checked = false; scanTaproot.checked = false
            nameEvm.text = ""; nameSegwit.text = ""; nameTaproot.text = ""
            var i = root.wallet ? root.profiles.findIndex(function(p) { return p.name === root.wallet.profile }) : -1
            walletType.currentIndex = i + 1
        }

        function line() {
            if (!started) return ""
            if (root.working && root.scanning.step === "unlock_key")
                return "Now scan the request in the Logos QR window with the wallet and confirm it, then hold its answer up to the camera: it gives this wallet's unlock key."
            if (root.working && root.scanView.active === true) {
                let s = root.scanView.seeing === true
                        ? "A code is in view: hold it steady."
                        : "No code in view yet: hold the wallet's account code up to the camera."
                if ((root.scanView.expected || 0) > 0)
                    s += " Read " + (root.scanView.received || 0) + " of " + root.scanView.expected + " parts."
                return s
            }
            if (root.working) return "Hold the wallet's account code up to the camera. The Logos QR window shows what it sees."
            if (root.scanning.state === "done") {
                let added = root.scanning.accounts || []
                let n = added.length
                let s = n === 1 ? "Account added." : "Added " + n + " accounts."
                if (root.scanning.unlockKey !== false) return s
                let fp = added.length ? (added[0].fingerprint || added[0].seed || "") : ""
                let w = root.wallets.find(function(x) { return x.fingerprint === fp }) || null
                return s + (w && w.profile === "keycard_shell"
                            ? " It gave no unlock key: give it from the wallet's card, or set a password for it in the Signer app, or its accounts can't be opened after a restart."
                            : " Wallets of this kind give no unlock key: set a password for it in the Signer app, or its accounts can't be opened after a restart.")
            }
            if (root.scanning.state === "failed") return "Not added: " + (root.scanning.error || "")
            if (root.scanning.state === "cancelled") return "Stopped. Nothing was added."
            return ""
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacing.small
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Show your wallet's account code, then hold it up to the camera. On a Keycard Shell: Connect software wallet."
            }
            LogosComboBox {
                id: walletType
                objectName: "walletType"
                Layout.fillWidth: true
                model: ["As its code says"].concat(root.profiles.map(function(p) { return p.label }))
                enabled: !root.working && !addSheet.submitting
            }
            RowLayout {
                LogosCheckbox { id: scanEvm; objectName: "scanEvm"; text: "Ethereum"; enabled: !root.working }
                LogosCheckbox { id: scanSegwit; objectName: "scanSegwit"; text: "Bitcoin · Native SegWit"; enabled: !root.working }
                LogosCheckbox { id: scanTaproot; objectName: "scanTaproot"; text: "Bitcoin · Taproot"; enabled: !root.working }
                LogosInfoButton {
                    objectName: "scanInfo"
                    title: "Adding accounts"
                    Accessible.name: "Help: Adding accounts"
                    text: "One code can hold several accounts: tick each kind you want. They are on the network "
                          + "the wallet is set to. Only public keys are kept, so apps can show addresses and ask "
                          + "the wallet to sign. Choose the wallet if its code doesn't say which it is: its "
                          + "requests are then sized for it."
                }
            }
            // A name for each account added, or none: the list then shows its kind.
            LogosTextField {
                id: nameEvm
                objectName: "scanNameEvm"
                Layout.fillWidth: true
                visible: scanEvm.checked
                placeholderText: "Ethereum account's name (optional)"
                textInput.maximumLength: 80
                enabled: !root.working
            }
            LogosTextField {
                id: nameSegwit
                objectName: "scanNameSegwit"
                Layout.fillWidth: true
                visible: scanSegwit.checked
                placeholderText: "Native SegWit account's name (optional)"
                textInput.maximumLength: 80
                enabled: !root.working
            }
            LogosTextField {
                id: nameTaproot
                objectName: "scanNameTaproot"
                Layout.fillWidth: true
                visible: scanTaproot.checked
                placeholderText: "Taproot account's name (optional)"
                textInput.maximumLength: 80
                enabled: !root.working
            }
            LogosText {
                objectName: "scanLine"
                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: root.scanning.state === "failed" ? Theme.palette.error : Theme.palette.text
                text: addSheet.line()
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton {
                    objectName: "addDone"
                    text: "Done"
                    visible: !root.working
                    enabled: !addSheet.submitting
                    onClicked: addSheet.close()
                }
                LogosButton {
                    objectName: "stopScan"
                    text: "Stop"
                    visible: root.working
                    onClicked: root.backend.cancelScan()
                }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "scanButton"
                    text: "Read the wallet's code"
                    enabled: root.ready && !root.working && !addSheet.submitting
                             && (scanEvm.checked || scanSegwit.checked || scanTaproot.checked)
                    onClicked: {
                        var families = []
                        var labels = {}
                        if (scanEvm.checked) { families.push("evm"); labels.evm = nameEvm.text }
                        if (scanSegwit.checked) { families.push("bitcoin"); labels.bitcoin = nameSegwit.text }
                        if (scanTaproot.checked) { families.push("bitcoin_taproot"); labels.bitcoin_taproot = nameTaproot.text }
                        var profile = walletType.currentIndex > 0 ? root.profiles[walletType.currentIndex - 1].name : ""
                        addSheet.submitting = true
                        addSheet.started = true
                        logos.watch(root.backend.scan(JSON.stringify(families), profile, JSON.stringify(labels)),
                                    function (ok) { addSheet.submitting = false })
                    }
                }
            }
        }
    }

    // ── managing a wallet ────────────────────────────────────────────────────
    LogosDialog {
        id: manageSheet
        objectName: "manageWalletDialog"
        title: "Manage · " + root.walletName(root.wallet)
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 620)
        height: Math.min(parent.height - 40, 620)
        contentItem: ColumnLayout {
            LogosScrollView {
                id: manageScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: manageScroll.availableWidth
                    spacing: Theme.spacing.small
                    LogosText {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                        color: Theme.palette.textSecondary
                        text: root.wallet ? "Master fingerprint: " + root.wallet.fingerprint
                                            + (root.wallet.label ? " · requests sized for a " + root.wallet.label : "") : ""
                    }
                    // Only once the signer manager says.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !!root.wallet && root.wallet.unlockKey !== undefined
                        LogosText {
                            objectName: "unlockKeyLine"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            wrapMode: Text.WordWrap
                            color: Theme.palette.textSecondary
                            text: !root.wallet ? ""
                                  : root.wallet.unlockKey ? "Its unlock key is given: the Signer app can unlock this wallet with it."
                                  : root.canGiveKey(root.wallet) ? "Its unlock key isn't given: the Signer app can unlock this wallet only by a password until it is."
                                  : "Wallets of this kind give no unlock key: the Signer app unlocks this wallet by a password."
                        }
                        LogosButton {
                            objectName: "giveKeyManage"
                            visible: root.canGiveKey(root.wallet)
                            text: "Give its unlock key…"
                            enabled: !root.working
                            onClicked: keySheet.open()
                        }
                    }
                    Repeater {
                        objectName: "manageAccounts"
                        model: (root.wallet && root.wallet.accounts) || []
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            LogosText {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                wrapMode: Text.WrapAnywhere
                                textFormat: Text.PlainText
                                text: (modelData.label || root.familyWords(modelData.family)) + "\n" + (modelData.address || modelData.path || modelData.id)
                            }
                            LogosButton {
                                objectName: "renameAccount_" + index
                                text: "Rename"
                                onClicked: {
                                    renameSheet.accountId = modelData.id
                                    renameSheet.accountLabel = modelData.label || ""
                                    renameSheet.accountDetails = modelData.address || modelData.path || modelData.id
                                    renameSheet.open()
                                }
                            }
                            LogosButton {
                                objectName: "removeAccount_" + index
                                text: "Remove"
                                onClicked: logos.watch(root.backend.removeAccount(modelData.id), function (gone) {})
                            }
                        }
                    }
                    LogosText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Theme.palette.textSecondary
                        text: "Removing an account hides it from apps. Nothing on the wallet changes, and you can add it again from its code."
                    }
                    LogosButton {
                        objectName: "forgetWallet"
                        text: "Forget wallet…"
                        enabled: !!root.wallet
                        onClicked: {
                            forgetSheet.fingerprint = root.selectedFingerprint
                            forgetSheet.walletLabel = root.walletName(root.wallet)
                            forgetSheet.open()
                        }
                    }
                    LogosText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        color: Theme.palette.error
                        text: root.ready ? root.backend.lastError : ""
                    }
                }
            }
            LogosButton { objectName: "manageDone"; text: "Done"; onClicked: manageSheet.close() }
        }
    }

    // ── a Keycard Shell's unlock key, after its add ──────────────────────────
    LogosDialog {
        id: keySheet
        objectName: "giveKeyDialog"
        title: "Give its unlock key · " + root.walletName(root.wallet)
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 580)
        closePolicy: root.working || submitting ? Popup.NoAutoClose : Popup.CloseOnEscape
        property bool submitting: false
        // Whether this opening started it, so an earlier scan's outcome isn't shown.
        property bool started: false
        onOpened: { submitting = false; started = false }

        function line() {
            if (!started) return ""
            if (root.working) return "Scan the request in the Logos QR window with the wallet and confirm it, then hold its answer up to the camera."
            if (root.scanning.state === "done") return "Unlock key given. The Signer app's Wallets tab shows how this wallet unlocks."
            if (root.scanning.state === "failed") return "Not given: " + (root.scanning.error || "")
            if (root.scanning.state === "cancelled") return "Stopped. Nothing was given."
            return ""
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacing.small
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "The wallet signs a message that moves no funds, and this computer works out the wallet's unlock key from its answer: the key it gives when it is added. The Signer app can then unlock this wallet with the wallet instead of a password."
            }
            LogosText {
                objectName: "giveKeyLine"
                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: root.scanning.state === "failed" ? Theme.palette.error : Theme.palette.text
                text: keySheet.line()
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton {
                    objectName: "giveKeyDone"
                    text: "Done"
                    visible: !root.working
                    enabled: !keySheet.submitting
                    onClicked: keySheet.close()
                }
                LogosButton {
                    objectName: "giveKeyStop"
                    text: "Stop"
                    visible: root.working
                    onClicked: root.backend.cancelScan()
                }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "giveKeyButton"
                    text: "Show the request"
                    enabled: root.ready && !root.working && !keySheet.submitting && root.canGiveKey(root.wallet)
                    onClicked: {
                        keySheet.submitting = true
                        keySheet.started = true
                        logos.watch(root.backend.giveUnlockKey(root.selectedFingerprint),
                                    function (ok) { keySheet.submitting = false })
                    }
                }
            }
        }
    }

    LogosDialog {
        id: renameSheet
        objectName: "renameAccountDialog"
        title: "Rename account"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 520)
        property string accountId: ""
        property string accountLabel: ""
        property string accountDetails: ""
        property bool saving: false
        property string errorText: ""
        closePolicy: saving ? Popup.NoAutoClose : Popup.CloseOnEscape
        onOpened: { accountName.text = accountLabel; errorText = ""; saving = false; accountName.forceActiveFocus() }
        contentItem: ColumnLayout {
            LogosText { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; text: renameSheet.accountDetails }
            LogosTextField {
                id: accountName
                objectName: "accountName"
                Layout.fillWidth: true
                placeholderText: "Account name"
                textInput.maximumLength: 80
                enabled: !renameSheet.saving
            }
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                text: "This name is saved on this computer and shown to apps. Leave it blank to use the default."
            }
            LogosText {
                Layout.fillWidth: true
                visible: !!text
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: Theme.palette.error
                text: renameSheet.errorText
            }
            RowLayout {
                LogosButton { text: "Cancel"; enabled: !renameSheet.saving; onClicked: renameSheet.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "saveAccountName"
                    text: renameSheet.saving ? "Saving…" : "Save name"
                    enabled: !renameSheet.saving
                    onClicked: {
                        renameSheet.saving = true
                        logos.watch(root.backend.renameAccount(renameSheet.accountId, accountName.text), function (ok) {
                            renameSheet.saving = false
                            if (ok) renameSheet.close()
                            else renameSheet.errorText = root.backend.lastError
                        })
                    }
                }
            }
        }
    }

    LogosDialog {
        id: forgetSheet
        objectName: "forgetWalletDialog"
        title: "Forget wallet?"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 580)
        property string fingerprint: ""
        property string walletLabel: ""
        property bool working: false
        onOpened: working = false
        contentItem: ColumnLayout {
            spacing: Theme.spacing.medium
            LogosText { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; font.bold: true; text: forgetSheet.walletLabel }
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Stop offering this wallet's accounts to apps and remove them from this computer. Nothing on the wallet is erased, and you can add its accounts again from its code."
            }
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: Theme.palette.error
                text: root.ready ? root.backend.lastError : ""
            }
            RowLayout {
                LogosButton { objectName: "cancelForgetWallet"; text: "Cancel"; enabled: !forgetSheet.working; onClicked: forgetSheet.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "confirmForgetWallet"
                    text: forgetSheet.working ? "Forgetting…" : "Forget wallet"
                    enabled: !forgetSheet.working
                    onClicked: {
                        forgetSheet.working = true
                        logos.watch(root.backend.forgetWallet(forgetSheet.fingerprint), function (ok) {
                            forgetSheet.working = false
                            if (ok) { forgetSheet.close(); manageSheet.close() }
                        })
                    }
                }
            }
        }
    }
}
