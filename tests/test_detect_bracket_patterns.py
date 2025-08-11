from lupa import LuaRuntime


def load_module(prefs):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua_globals = lua.globals()
    lua_globals.prefs = lua.table_from(prefs)
    lua.execute(
        'function import(name) '
        'if name == "LrPathUtils" then '
        'return { child = function(base, child) return base .. "/" .. child end } '
        'elseif name == "LrTasks" then '
        'return { pcall = pcall } '
        'elseif name == "LrPrefs" then '
        'return { prefsForPlugin = function() return prefs end } '
        'else return {} end end'
    )
    lua.execute("_PLUGIN={path='plugin/WildlifeAI.lrplugin'}")
    lua.execute('orig_dofile = dofile')
    lua.execute(
        'function dofile(path) '
        'if string.find(path, "utils/Log.lua") then '
        'return {info=function(...) end, debug=function(...) end, warning=function(...) end} '
        'else return orig_dofile(path) end end'
    )
    mod = lua.eval('dofile("plugin/WildlifeAI.lrplugin/BracketStacking.lua")')
    make_meta = lua.eval(
        'function(ts, ev) return {timestamp=ts, exposureValue=ev, orientation="horizontal"} end'
    )
    return lua, mod, make_meta


def test_sequence_exceeding_max_bracket_size_splits():
    prefs = {
        'enableBracketStacking': True,
        'minBracketSize': 3,
        'maxBracketSize': 3,
        'defaultBracketSize': 3,
        'customBracketSize': 3,
        'withinBracketInterval': 2,
        'individualBracketGap': 30,
        'panoramaBracketGap': 30,
        'useExposureValuesForDetection': True,
        'minExposureStep': 0.5,
        'maxExposureStep': 2.0,
        'minPanoramaPositions': 5,
        'maxPanoramaPositions': 20,
        'useOrientationAsPanoramaHint': False,
    }
    lua, mod, make_meta = load_module(prefs)
    exposures = [-1, 0, 1, -1, 0, 1, -1, 0, 1, -1]
    photo_data = lua.table_from([make_meta(i, ev) for i, ev in enumerate(exposures, 1)])
    result = mod.detectBracketsFromMetadata(photo_data, None)
    sequences = result['sequences']
    first_seq = sequences[1]
    brackets = first_seq['brackets']
    bracket_list = [brackets[i] for i in range(1, len(brackets) + 1)]
    assert len(bracket_list) == 3
