using UnityEngine;
using System.Collections.Generic;

// 5: cold mountain, remove mat16
// 7: castle interior
// 8: castle interior
// 9: castle interior
// 10: hazy maze cave
// 11: shifting sand land
// 12: pyramid interior
// 14: bob-omb battlefield
// 15: snowman's land
// 17: wet-dry
// 18: wet-dry city
// 19: jolly roger bay
// 21: tiny-huge
// 22: tiny-huge
// 24: tick tock clock
// 25: rainbow ride
// 26: castle exterior
// 27: bowser level
// 29: bowser level
// 31: bowser level
// 32: lethal lava exterior
// 33: volcano interior
// 35: sub exterior
// 36: whomp's fortress
// 38: ghost courtyard
// 39: slide
// 41: wing hat
// 42: bowser
// 43: rainbow cloud thing
// 44: bowser w/ lava
// 45: green bowser
// 46: tall tall mountain
// 47: straight slide
// 48: slide
// 49: slide
// 56: ghost house
// .. repeat

public class LevelDef {
    public int Index;
    public Vector3 CameraStart;
    public HashSet<int> RemoveMats;
}

public static class LevelDefs {
    public static Dictionary<string, LevelDef> Defs;

    public static string CurrentLevel;

    static LevelDefs() {
        Defs = new Dictionary<string, LevelDef>();
        Defs["Castle Exterior"] = new LevelDef() {
            Index = 26,
            CameraStart = new Vector3(17.5f, 2.7f, 39.1f),
            RemoveMats = new HashSet<int>(new int[] {
                2,
                5,
                18,
                23,
                24,
                25,
                26,
                27,
                28,
                29,
                30,
                31,
                32,
                33,
                34,
                36,
                37,
                38,
                39,
                40,
                41,
                42,
                43
            })
        };
        Defs["Bob-omb Battlefield"] = new LevelDef() {
            Index = 14,
            CameraStart = new Vector3(45.04f, 0.24f, 59.77f),
            RemoveMats = new HashSet<int>(new int[] {
               13,
               23,
               24,
               25,
               26,
               27,
               28,
               29,
               31,
               32,
               33,
               34,
               35,
               36,
               37,
               38,
               39,
               40,
               42,
               43,
               44,
               45,
               46,
               47,
               48,
               49,
               50,
               51,
               54,
               55,
               56,
               59,
               60,
               61,
               62,
               63,
               64,
               65,
               66,
               67,
               68,
               69,
               70,
               71,
               72,
               73
            })
        };
        Defs["Whomp's Fortress"] = new LevelDef() {
            Index = 36,
            CameraStart = new Vector3(-39.57f, 5.12f, 40.06f),
            RemoveMats = new HashSet<int>(new int[] {
               14,
               18,
               22,
               23,
               24,
               25,
               26,
               27,
               28,
               29,
               30,
               31,
               32,
               33,
               34,
               38,
               39,
               40,
               41,
               42,
               43,
               44,
               45,
               46,
               48,
               49,
               50,
               51,
               52,
               53,
               54,
               55,
               56,
               57,
               58,
               59,
               60,
               61,
               62,
            })
        };
        Defs["Cool, Cool Mountain"] = new LevelDef() {
            Index = 5,
            CameraStart = new Vector3(13.32f, 25.608f, -24.71f),
            RemoveMats = new HashSet<int>(new int[] {
               16,
               17,
               18,
               19,
               20,
               21,
               22,
               23,
               24,
               25,
               26,
               27,
               28,
               29,
               30,
               31,
               32,
               33,
               34,
               35,
               36,
               37,
               38,
               39,
               40,
               41,
               42,
               43,
               45,
               46,
               47,
               48,
               50,
               51,
               52,
               53,
               54,
               55,
               56,
               57,
               58,
               59
            })
        };
    }
}
