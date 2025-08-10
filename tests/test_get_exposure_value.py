import math
from lupa import LuaRuntime


def load_module():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        'function import(name) '
        'if name == "LrPathUtils" then '
        'return { child = function(base, child) return base .. "/" .. child end } '
        'elseif name == "LrTasks" then '
        'return { pcall = pcall } '
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
    make_photo = lua.eval(
        'function(ap, sh, iso) '
        'return {raw={aperture=ap, shutterSpeed=sh, isoSpeedRating=iso, dateTime=1}, '
        'formatted={fileName="f"}, '
        'getRawMetadata=function(self,key) return self.raw[key] end, '
        'getFormattedMetadata=function(self,key) return self.formatted[key] end} end'
    )
    return lua, mod, make_photo


def test_numeric_exposure():
    lua, mod, make_photo = load_module()
    photo = make_photo(2.8, 1/250, 100)
    res = mod.extractPhotoMetadata(lua.table_from([photo]))
    ev = res[1]['exposureValue']
    expected = math.log(2.8 * 2.8 / (1/250), 2) + math.log(100/100, 2)
    assert abs(ev - expected) < 1e-6


def test_string_exposure():
    lua, mod, make_photo = load_module()
    photo = make_photo('2.8', '1/250', '200')
    res = mod.extractPhotoMetadata(lua.table_from([photo]))
    ev = res[1]['exposureValue']
    expected = math.log(2.8 * 2.8 / (1/250), 2) + math.log(200/100, 2)
    assert abs(ev - expected) < 1e-6


def test_missing_metadata():
    lua, mod, make_photo = load_module()
    photo = make_photo(None, '1/250', 100)
    res = mod.extractPhotoMetadata(lua.table_from([photo]))
    assert res[1]['exposureValue'] is None
