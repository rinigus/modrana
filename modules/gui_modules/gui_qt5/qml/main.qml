import QtQuick 2.0
import QtQuick.Window 2.1
import io.thp.pyotherside 1.0
import UC 1.0
import "modrana_components"
import "backend"

ApplicationWindow {
    id : rWin

    title : "modRana"

    // properties
    property alias animate : animateProperty.value
    OptProp {
        id : animateProperty
        value : true
    }

    // debugging
    property variant showDebugButton : OptProp {value : false}
    property variant showUnfinishedPages : OptProp {value : false}
    //TODO: check if using .value has any performance impact to all
    //      those bindings in Tile
    property alias tileDebug : tileDebugProperty.value
    OptProp {
        id : tileDebugProperty
        value : false
    }
    property variant locationDebug : OptProp {value : false}

    // logging
    property variant log : PythonLog {}

    property int _landscapeDivider : rWin.platform.needsBackButton ? 5.5 : 8.0
    property int headerHeight : rWin.inPortrait ? height/8.0 : height/_landscapeDivider

    property variant c

    // properties that can be assigned a value
    // by packaging scripts for a given platform
    // -> who would ever want to pass arguments when
    //    running qml file, nonsense! :P
    // tl;dr; If we could easily pass arguments
    // to the QML file with qmlscene or sailfish-qml,
    // hacks like this would not be needed.
    property string _PYTHON_IMPORT_PATH_
    property string _PLATFORM_ID_

    Loader {
        id : platformLoader
    }
    //property variant platform : platformLoader.item
    property variant platform

    property variant mapPage

    property variant pages : {
        // pre-load the toplevel pages
        "MapPage" : mapPage
        /*
        "Menu" : loadPage("MenuPage"),
        "OptionsMenu" : loadPage("OptionsMenuPage"),
        "InfoMenu" : loadPage("InfoMenuPage"),
        "MapMenu" : loadPage("MapMenuPage"),
        "ModeMenu" : loadPage("ModeMenuPage"),
        */
    }

    // location
    property variant location : Location {}
    property variant position // full position object
    property variant pos // coordinate only
    // lastGoodPos needs to be always set,
    // by defaultBrno is used or last known saved position
    // and if available, the last known actual valid position
    property variant lastGoodPos : Coordinate {
        latitude : 49.2
        longitude : 16.616667
        altitude : 237.0
    }
    property real bearing
    // has fix is set to true once fix is acquired
    property bool hasFix : false
    property bool llValid : pos ? pos.isValid : false

    // theme
    property variant theme

    // map layers
    property variant layerTree : ListModel {}
    property variant layerDict

    //actions
    property variant actions : Actions {}

    // export the Python context so other elements can use
    // it without instantiating it themselves
    property alias python : python
    Python {
        id : python
        Component.onCompleted: {
            // add Python event handlers
            // - they will be called during modRana startup
            // - like this initial property values will be set
            python.setHandler("themeChanged", function(newTheme){
                rWin.log.info("theme changed to: " + newTheme.name + " (id: " + newTheme.id + ")")
                rWin.theme = newTheme
            })

            // import and initialize modRana,
            // taking any import overrides in account
            if (rWin._PYTHON_IMPORT_PATH_) {
                addImportPath(rWin._PYTHON_IMPORT_PATH_)
            } else {
                addImportPath('.')
            }
            importModule_sync('sys')
            importModule_sync('modrana')

            // fake the argv
            var fake_argv = '["modrana.py", "-u", "qt5"]'
            if (rWin._PLATFORM_ID_) {
                fake_argv = '["modrana.py", "-u", "qt5", "-d", "'+ rWin._PLATFORM_ID_ + '"]'
            }
            evaluate('setattr(sys, "argv" ,' + fake_argv +')')
            rWin.log.info('sys.argv faked')

            // start modRana
            call('modrana.start', [], rWin.__init__)
        }

        onError: {
            // when an exception is raised, this error handler will be called
            rWin.log.error('python error: ' + traceback);
        }
    }

    Button {
        anchors.top : parent.top
        anchors.right : parent.right
        visible : rWin.showDebugButton.value
        text : "debug"
        onClicked : {
            rWin.log.info("# starting the Python Debugger (PDB) shell")
            rWin.log.info("# to continue program execution, press c")
            // make sure the pdb module is imported
            python.importModule_sync('pdb')
            // start debugging
            python.call_sync('pdb.set_trace', [])

        }
    }

    Label {
        id : startingLabel
        anchors.horizontalCenter : parent.horizontalCenter
        anchors.verticalCenter : parent.verticalCenter
        anchors.right : parent.right
        font.pixelSize : 32
        text: "<b>starting modRana...</b>"
        width : parent.width
        horizontalAlignment : Text.AlignHCenter
        verticalAlignment : Text.AlignVCenter
    }

    // everything should be initialized by now,
    // including the Python backend
    Component.onCompleted: {
        //rWin.__init__()
    }

    function __init__() {
        // Do all startup tasks depending on the Python
        // backend being loaded
        // TODO: fade in/out + spinner
        startingLabel.visible = false
        // the Python-side logging system should be now up and running
        rWin.log.backendAvailable = true
        rWin.log.info("__init__ running")

        // load the constants
        // (including the GUI style constants)
        rWin.c = python.call_sync("modrana.gui.getConstants", [])

        // init miscellaneous other toplevel properties
        animateProperty.key = "QMLAnimate"
        showDebugButton.key = "showQt5GUIDebugButton"
        showUnfinishedPages.key = "showQt5GUIUnfinishedPages"
        tileDebugProperty.key = "showQt5TileDebug"
        locationDebug.key = "gpsDebugEnabled"

        // the various property encapsulation items need the
        // Python backend to be initialized, so we can load them now
        //platformLoader.source = "Platform.qml"
        rWin.platform = loadQMLFile("backend/Platform.qml")
        _init_location()

        // if on a platform that is not fullscreen-only,
        // set some reasonable default size for the window
        var fullscreenOnly = python.call_sync("modrana.dmod.fullscreenOnly", [])
        if (!fullscreenOnly) {
            rWin.width = 640
            rWin.height = 480
        }

        if (!fullscreenOnly) {
            // no need to trigger fullscreen or even read the value if the platform is fullscreen only
            var startInFullscreen = python.call_sync("modrana.gui.shouldStartInFullscreen", [])
            if (startInFullscreen) {
                rWin.setFullscreen(5) // 5 == fullscreen
            }
        }
        // the map page needs to be loaded after
        // location is initialized, so that
        // it picks up the correct position
        //rWin.mapPage = loadPage("MapPage")
        //rWin.initialPage = rWin.mapPage
        //rWin.pushPage(rWin.mapPage, rWin.animate)
        rWin.mapPage = rWin.pushPage(loadPage("MapPage"), rWin.animate)

        // now asynchronously load other stuff we might
        // need in the future

        loadMapLayers()
    }

    function _init_location() {
        // initialize the location module,
        // this also start localisation,
        // if enabled
        rWin.location.__init__()
    }

    //property variant mapPage : loadPage("MapPage")

    function loadQMLFile(filename, quiet) {
        var component = Qt.createComponent(filename);
        if (component.status == Component.Ready) {
            return component.createObject(rWin);
        } else {
            if (!quiet) {
                rWin.log.error("loading QML file failed: " + filename)
                rWin.log.error("error: " + component.errorString())
            }
            return null
        }
    }

    function loadPage(pageName) {
        rWin.log.info("loading page: " + pageName)
        return loadQMLFile(pageName + ".qml")
    }
    /*
    function loadPage(pageName) {
        rWin.log.info("loading page: " + pageName)
        var component = Qt.createComponent(pageName + ".qml");
        if (component.status == Component.Ready) {
            return component.createObject(rWin);
        } else {
            rWin.log.error("loading page failed: " + pageName + ".qml")
            rWin.log.error("error: " + component.errorString())
            return null
        }
    }
    */

    /* looks like object ids can't be stored in ListElements,
     so we need this function to return corresponding menu pages
     for names given by a string
    */

    function getPage(pageName) {
        rWin.log.debug("GET PAGE")
        rWin.log.debug(pageName)

        var newPage
        if (pageName == null) { //signal that we should return to the map page
            newPage = mapPage
        } else { // load a page
            var fullPageName = pageName + "Page"
            newPage = pages[pageName]
            if (!newPage) { // is the page cached ?
                // load the page and cache it
                newPage = loadPage(fullPageName)
                if (newPage) { // loading successful
                    pages[pageName] = newPage // cache the page
                    rWin.log.debug("page cached: " + pageName)
                } else { // loading failed, go to mapPage
                    newPage = null
                    rWin.log.debug(pageName + " loading failed, using mapPage")
                }
            }
        }
        rWin.log.debug("RETURN PAGE")
        rWin.log.debug(newPage)
        return newPage

    /* TODO: some pages are not so often visited pages so they could
    be loaded dynamically from their QML files ?
    -> also, a loader pool might be used as a rudimentary page cache,
    but this might not be needed if the speed is found to be adequate */
    }

    function push(pageName) {
        // push page by name
        //
        // TODO: instantiate pages that are not in the
        // dictionary
        if (pageName == null) { // null -> back to map
            //TODO: check if the stack can over-fil
            //console.log("BACK TO MAP")
            rWin.pageStack.pop(rWin.mapPage,!animate)
        } else {
            rWin.log.debug("PUSH " + pageName)
            rWin.pushPageInstance(rWin.getPage(pageName))
        }
    }

    function pushPageInstance(pageInstance) {
        // push page instance to page stack
        if (pageInstance) {
            rWin.pushPage(pageInstance, null, !rWin.animate)
        } else {
            // page instance not valid, go back to map
            rWin.pageStack.pop(rWin.mapPage, !animate)
        }
    }

    // Working with options
    function get(key, default_value, callback) {
        //rWin.log.debug("get " + callback)
        python.call("modrana.gui.get", [key, default_value], callback)
        return default_value
    }

    function get_auto(key, default_value, target_property) {
        //python.call("modrana.gui.get", [key, default_value], callback)
        console.log("get called")
        console.log(key)
        console.log(default_value)
        console.log(target_property)
        python.call("modrana.gui._get", [key, default_value], function(returned_value) {
            console.log("callback running")
            console.log(target_property)
            console.log(returned_value)
            console.log("done running")
            //target_property=returned_value
            target_property=9001
        })
        return default_value
    }

    function get_sync(key, default_value, callback) {
        return python.call_sync("modrana.gui.get", [key, default_value])
    }

    function set(key, value, callback) {
        python.call("modrana.gui.set", [key, value], function(){
            // there seem to be some issues with proper shutdown
            // so save after set for now
            python.call("modrana.modrana._saveOptions", [])
            if (callback) {
                callback()
            }
        })
    }

    function set_sync(key, value) {
        python.call_sync("modrana.gui.set", [key, value])
        // there seem to be some issues with proper shutdown
        // so save after set for now
        python.call_sync("modrana.modrana.self._saveOptions", [])
    }

    function dcall(functionName, functionArgs, defaultValue, callback) {
        // asynchronous call with immediate default value return
        // * run functionName with functionArgs asynchronously
        // * once the call is dispatched, return default_value
        // * and once the function returns, callback is called
        //
        // The main uses case is to asynchronously initialize properties
        // from Python data once an element is loaded. At first default values are used,
        // that are replaced by the real values once the Python call finishes.
        // Like this, element loading does not have to wait for Python.

        rWin.python.call(functionName, functionArgs, callback)
        return defaultValue
    }

    function loadMapLayers () {
        // asynchronously populate the layer tree
        rWin.python.call(
            "modrana.gui.modules.mapLayers.getLayerTree", [], function(results){
                rWin.layerTree.clear()
                for (var i=0; i<results.length; i++) {
                    rWin.layerTree.append(results[i]);
                }
                rWin.log.info("layer tree loaded")
                // now that we have the layer dict, restore the last used layer
                restoreLastUsedLayer()
            }
        )
        // asynchronously populate the layer dict
        rWin.python.call(
            "modrana.gui.modules.mapLayers.getDictOfLayerDicts", [], function(results){
                rWin.layerDict = results
                rWin.log.info("layer dict loaded")
            }
        )
    }

    function restoreLastUsedLayer() {
        // restore last used map layer
        // (the layer dict must be already loaded for this to work)
        rWin.get("layer", "mapnik", function(layerId){
            rWin.log.info("restoring last used map layer: " + layerId)
            rWin.mapPage.getMap().setLayerById(0,layerId)
        })
    }

    property variant _lastVisibility

    function toggleFullscreen() {
        // 2 = windowed
        // 3 = minimized
        // 4 = maximized
        // 5 = fullscreen
        // 1 = auto
        // 0 = hidden
        if (rWin.visibility==5) {
            // restore previous state,
            // provided it is not fullscreen
            if(_lastVisibility==5) {
                rWin.visibility = 2
            } else {
                rWin.visibility = rWin._lastVisibility
            }
        } else { // switch to fullscreen
            rWin.visibility = 5
        }
        rWin._lastVisibility = rWin.visibility
    }

    function setFullscreen(value) {
        //TODO: value checking :D
        rWin.visibility = value
        rWin._lastVisibility = rWin.visibility
    }

    function notify(message, timeout) {
        rWin.log.warning("notification skipped (fixme): " + message)
    }
}

