import QtQuick 2.15
import QtQuick.Controls 2.15

// Northling Midnight — экран входа SDDM.
// Только QtQuick/Controls (без GraphicalEffects), чтобы работало и на Qt5, и на Qt6.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0E0A24"

    readonly property color lavender: "#A78BFA"
    readonly property color sky: "#82BFFF"
    readonly property color pink: "#D284E5"
    readonly property color text: "#E5E7F5"
    readonly property color dim: "#9E94CD"
    readonly property string fontName: "JetBrainsMono Nerd Font"
    property int sessionIdx: sessionModel.lastIndex

    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
    }
    // Норт — маскот системы
    Image {
        source: "north.png"
        height: parent.height * 0.42
        fillMode: Image.PreserveAspectFit
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 36
        smooth: true
    }
    // затемнение, чтобы форма читалась на любых обоях
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#990E0A24" }
            GradientStop { position: 1.0; color: "#E60E0A24" }
        }
    }

    // ── часы слева сверху ──
    Column {
        x: 72; y: 64
        spacing: 2
        Text {
            id: clockText
            color: root.text; font.family: root.fontName; font.pixelSize: 84; font.bold: true
        }
        Text {
            id: dateText
            color: root.lavender; font.family: root.fontName; font.pixelSize: 20
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            clockText.text = Qt.formatTime(d, "HH:mm")
            dateText.text = Qt.formatDate(d, "dddd, d MMMM")
        }
    }

    // ── карточка входа ──
    Rectangle {
        id: card
        width: 420; height: 330
        anchors.centerIn: parent
        radius: 28
        color: "#CC0E0A24"
        border.color: "#55A78BFA"
        border.width: 1
        opacity: 0
        property real slide: 24
        transform: Translate { y: card.slide }

        ParallelAnimation {
            id: intro
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 650; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "slide"; to: 0; duration: 650; easing.type: Easing.OutBack }
        }

        Column {
            anchors.centerIn: parent
            spacing: 16
            width: parent.width - 64

            Text {
                text: "n."
                color: root.pink; font.family: root.fontName; font.pixelSize: 40; font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            TextField {
                id: userField
                width: parent.width; height: 46
                text: userModel.lastUser
                placeholderText: "Пользователь"
                color: root.text; placeholderTextColor: root.dim
                font.family: root.fontName; font.pixelSize: 15
                leftPadding: 18
                background: Rectangle {
                    radius: 23; color: "#33342676"
                    border.width: 1; border.color: userField.activeFocus ? root.lavender : "#44A78BFA"
                }
                KeyNavigation.tab: passField
            }

            TextField {
                id: passField
                width: parent.width; height: 46
                echoMode: TextInput.Password
                placeholderText: "Пароль"
                color: root.text; placeholderTextColor: root.dim
                font.family: root.fontName; font.pixelSize: 15
                leftPadding: 18
                background: Rectangle {
                    radius: 23; color: "#33342676"
                    border.width: 1; border.color: passField.activeFocus ? root.sky : "#44A78BFA"
                }
                onAccepted: sddm.login(userField.text, passField.text, root.sessionIdx)
                KeyNavigation.tab: sessionBox
            }

            Text {
                id: errorText
                text: ""
                color: "#F27A9C"; font.family: root.fontName; font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                height: 16
            }

            Rectangle {
                width: parent.width; height: 46; radius: 23
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.lavender }
                    GradientStop { position: 1.0; color: root.sky }
                }
                opacity: loginArea.pressed ? 0.8 : (loginArea.containsMouse ? 1.0 : 0.92)
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "Войти"
                    color: "#0E0A24"; font.family: root.fontName; font.pixelSize: 16; font.bold: true
                }
                MouseArea {
                    id: loginArea
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: sddm.login(userField.text, passField.text, root.sessionIdx)
                }
            }
        }
    }

    // ── выбор сессии и питание внизу ──
    ComboBox {
        id: sessionBox
        x: 72; y: parent.height - 96
        width: 240; height: 40
        model: sessionModel
        textRole: "name"
        currentIndex: sessionModel.lastIndex
        onActivated: root.sessionIdx = currentIndex
        background: Rectangle { radius: 20; color: "#33342676"; border.color: "#44A78BFA"; border.width: 1 }
        contentItem: Text {
            leftPadding: 16
            text: sessionBox.displayText
            color: "#C4B8F5"; font.family: root.fontName; font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
        }
        delegate: ItemDelegate {
            width: sessionBox.width
            contentItem: Text {
                text: model.name
                color: root.text; font.family: root.fontName; font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: parent.hovered ? "#34304F" : "#0E0A24" }
        }
        popup: Popup {
            y: -height
            width: sessionBox.width
            padding: 1
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: sessionBox.popup.visible ? sessionBox.delegateModel : null
            }
            background: Rectangle { color: "#0E0A24"; border.color: "#55A78BFA"; radius: 14 }
        }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: 72
        y: parent.height - 96
        spacing: 12
        Repeater {
            model: [
                { label: "Сон",           act: 0, ok: sddm.canSuspend },
                { label: "Перезагрузка",  act: 1, ok: sddm.canReboot },
                { label: "Выключить",     act: 2, ok: sddm.canPowerOff }
            ]
            delegate: Rectangle {
                visible: modelData.ok
                width: lbl.implicitWidth + 36; height: 40; radius: 20
                color: ma.containsMouse ? "#55342676" : "#33342676"
                border.color: ma.containsMouse ? (modelData.act === 2 ? "#F27A9C" : root.lavender) : "#44A78BFA"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: modelData.label
                    color: root.text; font.family: root.fontName; font.pixelSize: 13
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (modelData.act === 0) sddm.suspend()
                        else if (modelData.act === 1) sddm.reboot()
                        else sddm.powerOff()
                    }
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorText.text = "Неверный пароль"
            passField.text = ""
            passField.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        intro.start()
        if (userField.text.length > 0) passField.forceActiveFocus()
        else userField.forceActiveFocus()
    }
}
