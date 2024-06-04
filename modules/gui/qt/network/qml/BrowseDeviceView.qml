/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

import QtQuick

import org.videolan.vlc 0.1


import "qrc:///VLC/Style/"
import "qrc:///VLC/Widgets/" as Widgets
import "qrc:///VLC/Util/"    as Util

FocusScope {
    id: root

    // Properties

    required property BaseModel model

    readonly property int rowHeight: _currentView?.rowHeight ?? 0

    readonly property int contentHeight: _currentView?.contentHeight ?? 0

    readonly property int contentLeftMargin: _currentView?.contentLeftMargin ?? 0
    readonly property int contentRightMargin: _currentView?.contentRightMargin ?? 0

    property int displayMarginEnd: 0

    readonly property int currentIndex: _currentView?.currentIndex ?? -1

    property int maximumRows: -1

    readonly property int maximumCount: _currentView?.maximumCount ?? -1

    readonly property int nbItemPerRow: _currentView?.nbItemPerRow ?? 1

    property bool isSearchable: true

    property Component header: Widgets.ViewHeader {
        view: root

        text: root.title

        seeAllButton.visible: root.model.count < root.model.maximumCount

        Navigation.parentItem: root

        Navigation.downAction: function() {
            view.setCurrentItemFocus(Qt.TabFocusReason)
        }

        onSeeAllButtonClicked: reason => root.seeAll(reason)
    }

    property string title

    // Aliases

    property alias leftPadding: view.leftPadding
    property alias rightPadding: view.rightPadding

    // Private

    property alias _currentView: view.currentItem

    // Signals

    signal browse(var tree, int reason)

    signal seeAll(int reason)

    // Events

    onFocusChanged: {
        if (activeFocus === false || model.count === 0 || model.currentIndex !== -1)
            return

        model.currentIndex = 0
    }

    // Connections

    Connections {
        target: MainCtx

        function onGridViewChanged() {
            if (MainCtx.gridView) view.replace(grid)
            else                  view.replace(list)
        }
    }

    // Functions

    function playAt(index) {
        model.addAndPlay(index)
    }

    function setCurrentItemFocus(reason) {
        _currentView.setCurrentItemFocus(reason)
    }

    function getItemY(index) {
        if (_currentView === null)
            return 0

        return _currentView.getItemY(index)
    }

    // Events

    function onAction(index) {
        const indexes = modelSelect.selectedIndexes

        if (indexes.length > 1) {
            model.addAndPlay(indexes)

            return
        }

        const data = model.getDataAt(index)

        const type = data.type

        if (type === NetworkMediaModel.TYPE_DIRECTORY || type === NetworkMediaModel.TYPE_NODE)
            browse(data.tree, Qt.TabFocusReason)
        else
            playAt(index);
    }

    function onClicked(model, index, modifier) {
        modelSelect.updateSelection(modifier, model.currentIndex, index)

        model.currentIndex = index

        forceActiveFocus()
    }

    function onDoubleClicked(model, index) {
        const type = model.type

        if (type === NetworkMediaModel.TYPE_NODE || type === NetworkMediaModel.TYPE_DIRECTORY)
            browse(model.tree, Qt.MouseFocusReason)
        else
            playAt(index);
    }

    // Children

    ListSelectionModel {
        id: modelSelect

        model: root.model
    }

    Widgets.StackViewExt {
        id: view

        anchors.fill: parent

        focus: (model.count !== 0)

        initialItem: (MainCtx.gridView) ? grid : list
    }

    Component {
        id: grid

        Widgets.ExpandGridItemView {
            id: gridView

            basePictureWidth: VLCStyle.gridCover_network_width
            basePictureHeight: VLCStyle.gridCover_network_height

            maxNbItemPerRow: 12

            readonly property int maximumCount: (root.maximumRows === -1)
                                                ? -1
                                                : root.maximumRows * nbItemPerRow

            displayMarginEnd: root.displayMarginEnd

            model: root.model

            headerDelegate: root.header

            selectionModel: modelSelect

            Navigation.parentItem: root

            Navigation.upItem: headerItem

            onActionAtIndex: (index) => { root.onAction(index) }

            delegate: NetworkGridItem {
                width: gridView.cellWidth;
                height: gridView.cellHeight;

                pictureWidth: gridView.maxPictureWidth
                pictureHeight: gridView.maxPictureHeight

                onItemClicked: (modifier) => { root.onClicked(model, index, modifier) }

                onItemDoubleClicked: root.onDoubleClicked(model, index)

                onPlayClicked: root.playAt(index)
            }
        }
    }

    Component {
        id: list

        Widgets.KeyNavigableTableView {
            id: listView

            // Properties

            readonly property int maximumCount: root.maximumRows

            readonly property int nbItemPerRow: 1

            property var _modelSmall: [{
                weight: 1,

                model: ({
                    criteria: "name",

                    title: "name",

                    subCriterias: [ "mrl" ],

                    text: qsTr("Name"),

                    headerDelegate: artworkHeader,
                    colDelegate: artworkColumn
                })
            }]

            property var _modelMedium: [{
                size: 1,

                model: {
                    criteria: "artwork",

                    text: qsTr("Cover"),

                    isSortable: false,

                    headerDelegate: artworkHeader,
                    colDelegate: artworkColumn
                }
            }, {
                weight: 1,

                model: {
                    criteria: "name",

                    text: qsTr("Name")
                }
            }, {
                weight: 1,

                model: {
                    criteria: "mrl",

                    text: qsTr("Url"),

                    colDelegate: mrlColumn
                }
            }]

            // Settings

            rowHeight: VLCStyle.tableCoverRow_height

            displayMarginEnd: root.displayMarginEnd

            model: root.model

            sortModel: (availableRowWidth < VLCStyle.colWidth(4)) ? _modelSmall
                                                                  : _modelMedium

            header: root.header

            selectionModel: modelSelect

            Navigation.parentItem: root

            Navigation.upItem: headerItem

            onActionForSelection: selection => root.onAction(selection[0].row)

            onItemDoubleClicked: (index, model) => root.onDoubleClicked(model, index)

            Component {
                id: artworkHeader

                Widgets.TableHeaderDelegate {
                    Widgets.IconLabel {

                        height: VLCStyle.listAlbumCover_height
                        width: VLCStyle.listAlbumCover_width
                        anchors.centerIn: parent

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: VLCStyle.icon_tableHeader

                        text: VLCIcons.album_cover

                        color: parent.colorContext.fg.secondary
                    }
                }
            }

            Component {
                id: artworkColumn

                NetworkThumbnailItem { onPlayClicked: index => root.playAt(index) }
            }

            Component {
                id: mrlColumn

                Widgets.TableRowDelegate {
                    id: itemText

                    Widgets.TextAutoScroller {

                        anchors.fill: parent

                        clip: scrolling

                        label: itemLabel

                        forceScroll: itemText.currentlyFocused

                        Widgets.ListLabel {
                            id: itemLabel

                            anchors.verticalCenter: parent.verticalCenter

                            text: {
                                if (itemText.rowModel === null)
                                    return ""

                                const text = itemText.rowModel[itemText.colModel.criteria]

                                if (text.toString() === "vlc://nop")
                                    return ""
                                else
                                    return text
                            }

                            color: itemText.selected
                                ? itemText.colorContext.fg.highlight
                                : itemText.colorContext.fg.primary
                        }
                    }
                }
            }
        }
    }
}
