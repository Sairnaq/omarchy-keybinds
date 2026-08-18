import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string statusMessage: ""
  property var allBinds: []
  property var filteredBinds: []
  property string activeCategory: "All"
  property bool isEditing: false

  // Form inputs
  property string editCombo: ""
  property string editDesc: ""
  property string editAction: ""

  // Theme integration
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color accentColor: Color.accent || "#7fa961"
  property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))

  function open(payload) {
    opened = true
    statusMessage = ""
    isEditing = false
    activeCategory = "All"
    loadBinds()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function dismiss() {
    opened = false
    isEditing = false
    if (shell && shell.overlay) {
      shell.overlay.dismiss()
    }
  }

  function loadBinds() {
    statusMessage = "Loading keybindings..."
    fetchProcess.exec(["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/omarchy-keybinds/keybind-manager", "list"])
  }

  function applyFilter() {
    var q = searchInput.text.toLowerCase().trim()
    var result = []
    for (var i = 0; i < allBinds.length; i++) {
      var item = allBinds[i]
      var matchCat = (activeCategory === "All" || item.category === activeCategory)
      var matchQuery = (q === "" || item.combo.toLowerCase().indexOf(q) !== -1 || item.description.toLowerCase().indexOf(q) !== -1)
      if (matchCat && matchQuery) {
        result.push(item)
      }
    }
    filteredBinds = result
    statusMessage = "Showing " + filteredBinds.length + " shortcuts"
  }

  function saveBinding() {
    if (editCombo.trim() === "" || editAction.trim() === "") {
      statusMessage = "Error: Key combination and Action are required!"
      return
    }
    saveProcess.exec([
      "python3",
      Quickshell.env("HOME") + "/.config/omarchy/plugins/omarchy-keybinds/keybind-manager",
      "add",
      editCombo.trim(),
      editDesc.trim() || "Custom shortcut",
      editAction.trim()
    ])
  }

  function deleteBinding(combo) {
    deleteProcess.exec([
      "python3",
      Quickshell.env("HOME") + "/.config/omarchy/plugins/omarchy-keybinds/keybind-manager",
      "remove",
      combo
    ])
  }

  Process {
    id: fetchProcess
    stdout: StdioCollector {
      onDataReceived: function(data) {
        try {
          var parsed = JSON.parse(data)
          allBinds = parsed.binds || []
          applyFilter()
        } catch (e) {
          statusMessage = "Failed to parse keybindings"
        }
      }
    }
  }

  Process {
    id: saveProcess
    stdout: StdioCollector {
      onDataReceived: function(data) {
        isEditing = false
        statusMessage = "Saved & reloaded Hyprland!"
        loadBinds()
      }
    }
  }

  Process {
    id: deleteProcess
    stdout: StdioCollector {
      onDataReceived: function(data) {
        statusMessage = "Shortcut removed & reloaded!"
        loadBinds()
      }
    }
  }

  // Wayland Layer Shell Overlay Window
  PanelWindow {
    id: overlayWindow
    visible: root.opened
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    color: root.scrim

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Rectangle {
      id: card
      width: Math.min(850, parent.width - 40)
      height: Math.min(680, parent.height - 40)
      anchors.centerIn: parent
      color: root.background
      radius: Style.radius("menu") || 12
      border.color: root.accentColor
      border.width: 2

      MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) { mouse.accepted = true }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // Header
        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "⌨️ Hyprland & Omarchy Keybindings"
            color: root.foreground
            font.bold: true
            font.pixelSize: 18
            Layout.fillWidth: true
          }

          Button {
            text: root.isEditing ? "Cancel" : "+ Add Shortcut"
            onClicked: {
              if (root.isEditing) {
                root.isEditing = false
              } else {
                root.editCombo = ""
                root.editDesc = ""
                root.editAction = ""
                root.isEditing = true
              }
            }
          }

          Button {
            text: "✕"
            onClicked: root.dismiss()
          }
        }

        // Search Input
        TextField {
          id: searchInput
          Layout.fillWidth: true
          placeholderText: "Search shortcuts (e.g. SUPER + A, workspace, discord)..."
          color: root.foreground
          visible: !root.isEditing
          onTextChanged: root.applyFilter()
          Keys.onEscapePressed: root.dismiss()
        }

        // Category Filter Pills
        RowLayout {
          Layout.fillWidth: true
          visible: !root.isEditing
          spacing: 8

          Repeater {
            model: ["All", "Launchers", "Navigation", "Windows", "Utilities"]
            delegate: Button {
              text: modelData
              highlighted: root.activeCategory === modelData
              onClicked: {
                root.activeCategory = modelData
                root.applyFilter()
              }
            }
          }
        }

        // Form View (when Add/Edit is active)
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: root.isEditing
          spacing: 12

          Text {
            text: "Edit / Add Keybinding"
            color: root.accentColor
            font.bold: true
            font.pixelSize: 16
          }

          TextField {
            id: comboInput
            Layout.fillWidth: true
            placeholderText: "Key Combination (e.g. SUPER + SHIFT + Z)"
            text: root.editCombo
            onTextChanged: root.editCombo = text
          }

          TextField {
            id: descInput
            Layout.fillWidth: true
            placeholderText: "Description (e.g. My Custom App)"
            text: root.editDesc
            onTextChanged: root.editDesc = text
          }

          TextField {
            id: actionInput
            Layout.fillWidth: true
            placeholderText: "Command / Action (e.g. kitty -e btop, https://example.com)"
            text: root.editAction
            onTextChanged: root.editAction = text
          }

          RowLayout {
            spacing: 12
            Button {
              text: "💾 Save & Reload Hyprland"
              highlighted: true
              onClicked: root.saveBinding()
            }
            Button {
              text: "Cancel"
              onClicked: root.isEditing = false
            }
          }

          Item { Layout.fillHeight: true }
        }

        // Scrollable Keybindings List
        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: !root.isEditing
          clip: true

          ListView {
            id: listView
            width: parent.width
            model: root.filteredBinds
            spacing: 6

            delegate: Rectangle {
              width: listView.width
              height: 52
              radius: 8
              color: root.selectedBackground
              border.color: root.borderSpec ? root.borderSpec.color : "#404a40"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                // Key Combo Badge
                Rectangle {
                  implicitWidth: comboText.implicitWidth + 16
                  implicitHeight: 28
                  radius: 6
                  color: root.accentColor

                  Text {
                    id: comboText
                    anchors.centerIn: parent
                    text: modelData.combo
                    color: "#00070d"
                    font.bold: true
                    font.pixelSize: 12
                  }
                }

                // Description
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  Text {
                    text: modelData.description
                    color: root.foreground
                    font.bold: true
                    font.pixelSize: 13
                    elide: Text.ElideRight
                  }

                  Text {
                    text: modelData.category + (modelData.arg ? " • " + modelData.arg : "")
                    color: Color.menu.textMuted || "#a0a5a0"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                  }
                }

                // Edit Button
                Button {
                  text: "✏️"
                  implicitWidth: 34
                  implicitHeight: 28
                  onClicked: {
                    root.editCombo = modelData.combo
                    root.editDesc = modelData.description
                    root.editAction = modelData.arg || modelData.dispatcher || ""
                    root.isEditing = true
                  }
                }

                // Delete Button
                Button {
                  text: "🗑️"
                  implicitWidth: 34
                  implicitHeight: 28
                  onClicked: root.deleteBinding(modelData.combo)
                }
              }
            }
          }
        }

        // Status Bar Footer
        RowLayout {
          Layout.fillWidth: true

          Text {
            text: root.statusMessage
            color: Color.menu.textMuted || "#a0a5a0"
            font.italic: true
            font.pixelSize: 12
            Layout.fillWidth: true
          }

          Text {
            text: "Press Esc to exit"
            color: Color.menu.textMuted || "#a0a5a0"
            font.pixelSize: 11
          }
        }
      }
    }
  }
}
