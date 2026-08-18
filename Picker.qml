import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property string statusMessage: ""
  property var rawBinds: []
  property string activeCategory: "All"
  property bool isEditing: false

  // Form inputs
  property string editCombo: ""
  property string editDesc: ""
  property string editAction: ""

  property string manager: Quickshell.env("HOME") + "/.config/omarchy/plugins/omarchy-keybinds/keybind-manager"

  // Theme integration
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color accentColor: Color.accent || "#7fa961"

  function open(payload) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.statusMessage = ""
    root.isEditing = false
    root.activeCategory = "All"
    root.loadBinds()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    root.isEditing = false
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "omarchy-keybinds")
    }
  }

  function loadBinds() {
    root.statusMessage = "Loading shortcuts..."
    listModel.clear()
    fetchProc.running = true
  }

  function applyFilter() {
    listModel.clear()
    var q = root.filterText.toLowerCase().trim()
    for (var i = 0; i < rawBinds.length; i++) {
      var item = rawBinds[i]
      var matchCat = (activeCategory === "All" || item.category === activeCategory)
      var matchQuery = (q === "" || item.combo.toLowerCase().indexOf(q) !== -1 || item.description.toLowerCase().indexOf(q) !== -1)
      if (matchCat && matchQuery) {
        listModel.append(item)
      }
    }
    root.statusMessage = "Showing " + listModel.count + " shortcuts"
    if (root.selectedIndex >= listModel.count) root.selectedIndex = 0
  }

  function saveBinding() {
    if (root.editCombo.trim() === "" || root.editAction.trim() === "") {
      root.statusMessage = "Error: Key combo and Action are required!"
      return
    }
    saveProc.command = [
      "python3",
      root.manager,
      "add",
      root.editCombo.trim(),
      root.editDesc.trim() || "Custom shortcut",
      root.editAction.trim()
    ]
    saveProc.running = true
  }

  function deleteBinding(combo) {
    deleteProc.command = ["python3", root.manager, "remove", combo]
    deleteProc.running = true
  }

  ListModel {
    id: listModel
  }

  Process {
    id: fetchProc
    command: ["python3", root.manager, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text || "{}")
          root.rawBinds = parsed.binds || []
          root.applyFilter()
        } catch (e) {
          root.statusMessage = "Failed to parse keybindings"
        }
      }
    }
  }

  Process {
    id: saveProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isEditing = false
        root.statusMessage = "Saved & reloaded Hyprland!"
        root.loadBinds()
      }
    }
  }

  Process {
    id: deleteProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.statusMessage = "Shortcut removed & reloaded!"
        root.loadBinds()
      }
    }
  }

  // Overlay Window
  PanelWindow {
    id: panel
    visible: root.opened
    color: "transparent"
    WlrLayershell.namespace: "omarchy-keybinds"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(850), panel.width - Style.gapsOut * 2)
      height: Math.min(Style.space(680), panel.height - Style.gapsOut * 2)
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      radius: Style.cornerRadius
      padding: Style.spacing.panelPadding

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding

        // 1. Header Bar
        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(36)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "⌨️ Hyprland & Omarchy Keybindings"
            color: root.foreground
            font.bold: true
            font.pixelSize: Style.font.title || 16
          }

          Rectangle {
            anchors.right: closeBtn.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: addText.implicitWidth + Style.space(16)
            height: Style.space(28)
            radius: Style.cornerRadius || 6
            color: root.accentColor

            Text {
              id: addText
              anchors.centerIn: parent
              text: root.isEditing ? "Back to List" : "+ Add Shortcut"
              color: "#00070d"
              font.bold: true
              font.pixelSize: Style.font.caption || 11
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
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
          }

          Rectangle {
            id: closeBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.cornerRadius || 6
            color: root.selectedBackground

            Text {
              anchors.centerIn: parent
              text: "✕"
              color: root.foreground
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.dismiss()
            }
          }
        }

        // 2. Search Box (List Mode)
        Rectangle {
          id: searchBox
          anchors.top: header.bottom
          anchors.topMargin: Style.space(12)
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(36)
          radius: Style.cornerRadius || 8
          color: root.selectedBackground
          border.color: searchInput.activeFocus ? root.accentColor : "transparent"
          border.width: 1
          visible: !root.isEditing

          TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            verticalAlignment: TextInput.AlignVCenter
            color: root.foreground
            font.pixelSize: Style.font.body || 13
            clip: true

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Search shortcuts (e.g. SUPER + A, workspace, discord)..."
              color: Color.menu.textMuted || "#808580"
              font.pixelSize: Style.font.body || 13
              visible: !searchInput.text && !searchInput.activeFocus
            }

            onTextChanged: {
              root.filterText = text
              root.applyFilter()
            }

            Keys.onEscapePressed: root.dismiss()
            Keys.onDownPressed: {
              if (listModel.count > 0) {
                root.selectedIndex = Math.min(root.selectedIndex + 1, listModel.count - 1)
              }
            }
            Keys.onUpPressed: {
              if (listModel.count > 0) {
                root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
              }
            }
          }
        }

        // 3. Category Filter Tabs (List Mode)
        Row {
          id: categoryTabs
          anchors.top: searchBox.bottom
          anchors.topMargin: Style.space(10)
          anchors.left: parent.left
          spacing: Style.space(8)
          visible: !root.isEditing

          Repeater {
            model: ["All", "Launchers", "Navigation", "Windows", "Utilities"]
            delegate: Rectangle {
              width: catText.implicitWidth + Style.space(16)
              height: Style.space(26)
              radius: Style.space(6)
              color: root.activeCategory === modelData ? root.accentColor : root.selectedBackground

              Text {
                id: catText
                anchors.centerIn: parent
                text: modelData
                color: root.activeCategory === modelData ? "#00070d" : root.foreground
                font.bold: root.activeCategory === modelData
                font.pixelSize: Style.font.caption || 11
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.activeCategory = modelData
                  root.applyFilter()
                }
              }
            }
          }
        }

        // 4. Scrollable ListView (List Mode)
        ListView {
          id: listView
          anchors.top: categoryTabs.bottom
          anchors.topMargin: Style.space(12)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: footer.top
          anchors.bottomMargin: Style.space(8)
          visible: !root.isEditing
          clip: true
          model: listModel
          spacing: Style.space(6)

          delegate: Rectangle {
            width: listView.width
            height: Style.space(52)
            radius: Style.space(8)
            color: root.selectedIndex === index ? root.selectedBackground : "transparent"
            border.color: root.selectedIndex === index ? root.accentColor : "transparent"
            border.width: 1

            // Key Combo Badge
            Rectangle {
              id: badge
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: comboLabel.implicitWidth + Style.space(16)
              height: Style.space(28)
              radius: Style.space(6)
              color: root.accentColor

              Text {
                id: comboLabel
                anchors.centerIn: parent
                text: model.combo
                color: "#00070d"
                font.bold: true
                font.pixelSize: Style.font.caption || 11
              }
            }

            // Description & Action
            Column {
              anchors.left: badge.right
              anchors.leftMargin: Style.space(12)
              anchors.right: actionBtns.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: model.description
                color: root.foreground
                font.bold: true
                font.pixelSize: Style.font.body || 13
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: model.category + (model.arg ? " • " + model.arg : "")
                color: Color.menu.textMuted || "#909590"
                font.pixelSize: Style.font.caption || 10
                elide: Text.ElideRight
                width: parent.width
              }
            }

            // Action Buttons
            Row {
              id: actionBtns
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Rectangle {
                width: Style.space(32)
                height: Style.space(26)
                radius: Style.space(6)
                color: root.selectedBackground

                Text {
                  anchors.centerIn: parent
                  text: "✏️"
                  font.pixelSize: Style.font.caption || 11
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.editCombo = model.combo
                    root.editDesc = model.description
                    root.editAction = model.arg || model.dispatcher || ""
                    root.isEditing = true
                  }
                }
              }

              Rectangle {
                width: Style.space(32)
                height: Style.space(26)
                radius: Style.space(6)
                color: root.selectedBackground

                Text {
                  anchors.centerIn: parent
                  text: "🗑️"
                  font.pixelSize: Style.font.caption || 11
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.deleteBinding(model.combo)
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              z: -1
              onClicked: root.selectedIndex = index
            }
          }
        }

        // 5. Form View (Edit Mode)
        Column {
          id: formView
          anchors.top: header.bottom
          anchors.topMargin: Style.space(16)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: footer.top
          visible: root.isEditing
          spacing: Style.space(14)

          Text {
            text: "Edit / Add Keybinding"
            color: root.accentColor
            font.bold: true
            font.pixelSize: Style.font.title || 16
          }

          Text {
            text: "Key Combination (e.g. SUPER + SHIFT + Z):"
            color: root.foreground
            font.pixelSize: Style.font.caption || 11
          }

          Rectangle {
            width: parent.width
            height: Style.space(36)
            radius: Style.cornerRadius || 6
            color: root.selectedBackground

            TextInput {
              id: formCombo
              anchors.fill: parent
              anchors.margins: Style.space(10)
              verticalAlignment: TextInput.AlignVCenter
              color: root.foreground
              text: root.editCombo
              onTextChanged: root.editCombo = text
            }
          }

          Text {
            text: "Description (e.g. Launch Discord, Next Workspace):"
            color: root.foreground
            font.pixelSize: Style.font.caption || 11
          }

          Rectangle {
            width: parent.width
            height: Style.space(36)
            radius: Style.cornerRadius || 6
            color: root.selectedBackground

            TextInput {
              id: formDesc
              anchors.fill: parent
              anchors.margins: Style.space(10)
              verticalAlignment: TextInput.AlignVCenter
              color: root.foreground
              text: root.editDesc
              onTextChanged: root.editDesc = text
            }
          }

          Text {
            text: "Command / Action (e.g. omarchy-agent, https://x.com):"
            color: root.foreground
            font.pixelSize: Style.font.caption || 11
          }

          Rectangle {
            width: parent.width
            height: Style.space(36)
            radius: Style.cornerRadius || 6
            color: root.selectedBackground

            TextInput {
              id: formAction
              anchors.fill: parent
              anchors.margins: Style.space(10)
              verticalAlignment: TextInput.AlignVCenter
              color: root.foreground
              text: root.editAction
              onTextChanged: root.editAction = text
            }
          }

          Row {
            spacing: Style.space(12)

            Rectangle {
              width: saveBtnText.implicitWidth + Style.space(24)
              height: Style.space(36)
              radius: Style.cornerRadius || 6
              color: root.accentColor

              Text {
                id: saveBtnText
                anchors.centerIn: parent
                text: "💾 Save & Reload Hyprland"
                color: "#00070d"
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.saveBinding()
              }
            }

            Rectangle {
              width: cancelBtnText.implicitWidth + Style.space(24)
              height: Style.space(36)
              radius: Style.cornerRadius || 6
              color: root.selectedBackground

              Text {
                id: cancelBtnText
                anchors.centerIn: parent
                text: "Cancel"
                color: root.foreground
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.isEditing = false
              }
            }
          }
        }

        // 6. Footer Status Bar
        Item {
          id: footer
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(24)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusMessage
            color: Color.menu.textMuted || "#808580"
            font.italic: true
            font.pixelSize: Style.font.caption || 11
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Press Esc to exit"
            color: Color.menu.textMuted || "#808580"
            font.pixelSize: Style.font.caption || 10
          }
        }
      }
    }
  }
}
