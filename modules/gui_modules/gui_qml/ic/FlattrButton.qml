//FlattrButton.qml

import QtQuick 1.1
import "./qtc"

Rectangle {
    id : flattrButton
    color : flattrMA.pressed ? "limegreen" : "green"
    radius : 5
    width : 210 * C.style.m
    // height should be slightly smaller than for the flattr button
    height : C.style.button.generic.height * 0.75
    property string url : ""

    Label {
        anchors.horizontalCenter : parent.horizontalCenter
        anchors.verticalCenter : parent.verticalCenter
        text : "<h3>Flattr this !</h3>"
        color : "white"
    }
    MouseArea {
        id : flattrMA
        anchors.fill : parent
        onClicked : {
            console.log('Flattr button clicked')
            Qt.openUrlExternally(url)
        }
    }
}


