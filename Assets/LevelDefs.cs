using UnityEngine;
using System.Collections.Generic;

// 5: cold mountain - Finished
// 7: castle interior
// 8: castle interior
// 9: castle interior
// 10: hazy maze cave
// 11: shifting sand land
// 12: pyramid interior
// 14: bob-omb battlefield - Finished
// 15: snowman's land  - Finished
// 17: wet-dry - Finished
// 18: wet-dry city - Finished
// 19: jolly roger bay
// 21: tiny-huge - Finished
// 22: tiny-huge - Finished
// 24: tick tock clock - Finished
// 25: rainbow ride
// 26: castle exterior - Finished
// 27: bowser level
// 29: bowser level
// 31: bowser level
// 32: lethal lava exterior
// 33: volcano interior
// 35: sub exterior
// 36: whomp's fortress - Finished
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
    public bool Indoor = false;
    public float Scale = 1.0f;
    public Vector3 CameraStart;
    public string[] RemoveMats;
    public int LinkIndex = 0;
    public string[] LinkMats;
}

public static class LevelDefs {
    public static Dictionary<string, LevelDef> Defs;

    public static string CurrentLevel;

    static LevelDefs() {
        Defs = new Dictionary<string, LevelDef>();
        Defs["Castle Exterior"] = new LevelDef() {
            Index = 26,
            CameraStart = new Vector3(17.5f, 2.7f, 39.1f),
            RemoveMats = new string[] {
                "2",
                "5",
                "18",
                "23-34",
                "36-43",
            }
        };
        Defs["Bob-omb Battlefield"] = new LevelDef() {
            Index = 14,
            CameraStart = new Vector3(45.04f, 0.24f, 59.77f),
            RemoveMats = new string[] {
                "13",
                "23-29",
                "31-40",
                "42-51",
                "54-56",
                "59-73",
            }
        };
        Defs["Whomp's Fortress"] = new LevelDef() {
            Index = 36,
            CameraStart = new Vector3(-39.57f, 5.12f, 40.06f),
            RemoveMats = new string[] {
                "14",
                "18",
                "22-34",
                "38-46",
                "48-62",
            }
        };
        Defs["Cool, Cool Mountain"] = new LevelDef() {
            Index = 5,
            CameraStart = new Vector3(13.32f, 25.608f, -24.71f),
            RemoveMats = new string[] {
                "16-43",
                "45-48",
                "50-59",
            }
        };
        Defs["Tiny-Huge Island (Huge)"] = new LevelDef() {
            Index = 21,
            CameraStart = new Vector3(72.03f, -29.69f, 72.42f),
            RemoveMats = new string[] {
                "12",
                "15-35",
                "37-42",
                "44-62",
                "65",
            }
        };
        Defs["Tiny-Huge Island (Tiny)"] = new LevelDef() {
            Index = 22,
            CameraStart = new Vector3(16.58f, -7.42f, 18.45f),
            Scale = 0.25f,
            RemoveMats = new string[] {
                "12",
                "15-20",
                "23-54",
            }
        };
        /*Defs["Hazy Maze Cave"] = new LevelDef() {
            Index = 10,
            CameraStart = new Vector3(73.27f, 21.61f, 74.48f),
            Indoor = true,
            RemoveMats = new string[] {
                "38-62"
            }
        };*/
        Defs["Snowman's Land"] = new LevelDef() {
            Index = 15,
            CameraStart = new Vector3(-58.0f, 10.24f, 6.08f),
            RemoveMats = new string[] {
                "12-13",
                "17-37",
                "39-57",
            }
        };
        Defs["Wet-Dry World"] = new LevelDef() {
            Index = 17,
            CameraStart = new Vector3(-34.08f, 0.64f, 2.94f),
            Indoor = true,
            LinkIndex = 18,
            RemoveMats = new string[] {
                "15-16",
                "21-28",
                "31-52",
                "55-59",
                "62-63",
            },
            LinkMats = new string[] {
                "17-18",
                "20-24",
                "27-40",
            },
        };
        /*Defs["Tall, Tall Mountain"] = new LevelDef() {
            Index = 46,
            Indoor = false,
            RemoveMats = new string[] {
                "6-11",
                "13-17",
                "20-23",
                "25-30",
                "32-41",
                "46-53",
            }
        };*/
        Defs["Tick Tock Clock"] = new LevelDef() {
            Index = 24,
            CameraStart = new Vector3(-13.78f, -48.22f, -0.13f),
            Indoor = true,
            RemoveMats = new string[] {
                "16-17",
                "20-21",
                "24-42",
                "44-53"
            }
        };
    }
}
