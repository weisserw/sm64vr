module m64.collision;
import std.stream;
import m64.binarystream;
import m64.rom;
import m64.script;

/* Sources:
 * http://acmlm.no-ip.org/board/thread.php?id=1657&page=4
 * Flatworld Battlefield Commented Data (VL-Tone).
 */

/* TODO name classes
0000: Normal (Slippery in Slide levels, when 0x31=0006) 
000E: Water currents (8 bytes per tri) the two last bytes of each triangle defines direction and force of current 
002A: Un-climbable hill 
0015: Climbable hills 
0014: Slippery hill 
0013: Very slippery hill 
0012: Falling in void (Haunted House) 
001B: Switches to area 1 (Used in Wet/Dry World) 
001C: Switches to area 2 (Used in Wet/Dry World and Tall Tall slide to seemingly switch area) 
001D: Switches to area 3 (Used in Tall Tall slide to seemingly switch area) 
001E: Switches to area 4 (Used in Tall Tall slide to seemingly switch area) 
0028: Wall/fence 
0029: Grass/flat 
002C: Lethal ice 
0001: Lethal ice/ Lava 
0005: Mario can hang from the ceiling 
000A: Bottom of level (death) 
0030: Flat 
0036,0037: snowy ice stuff 
002E: Icy 
0033: Starting line in Princess Secret Slide 
0034: Finish line in Princess Secret Slide 
0079: Flat non-slippery floor in Princess Secret Slide 
0065: Top of Bob Omb Battlefield mountain wide angle camera 
0066: Walls Tiny Huge Island area 3 
006F: Camera turn in Bowser Course 1 
0070: Camera turns in BoB 
0075: Camera stuff Cool Cool Mountain 
007B: Vanishing walls 
00D0: Limited camera movements in narrow hallways (part of Hazy Maze Cave) 
00A6-00Cx: Painting warps areas (in front) 
00D3-00F8: Painting warps areas (behind) 
00FD: Pool Warp in Hazy Maze Cave
*/

struct Triangle
{
	ushort v1, v2, v3;
}

struct TrianglePlus
{
	ushort v1, v2, v3, extra;
}

class CollisionData : Script!CollisionCommand, IExportable
{
	/* !! IExportable implementation !! */
	string exportType()
	{
		return "Collision";
	}

	string exportExtension()
	{
		return "obj";
	}

	void exportTo(Stream s)
	{
		foreach (cmd; commands)
			cmd.exportToObj(s);
	}
}

class CollisionCommand : ScriptCommand
{
	static CollisionCommand readOpcode(RomContext ctx, BinaryStream s)
	{
		ushort opcode = s.get!ushort;
		switch (opcode)
		{
			case 0x000E:
			case 0x002C:
			case 0x0024:
			case 0x0025:
			case 0x0027:
			case 0x002D:
				return new CollisionTerrainPlus;

			case 0x0040:
				return new CollisionLoadVertices;

			case 0x0041:
				return new CollisionEnd; // (TODO?)

			default:
				return new CollisionTerrain; // TODO
				//throw new Exception(format("Unknown collision opcode [%.4X] (%s)", opcode, s.getSomeData()));
		}
	}

	override uint opcodeSize()
	{
		return 2 + size();
	}

	abstract void exportToObj(Stream s);
}

class CollisionTerrain : CollisionCommand
{
	Triangle[] triangles;

	override void read(RomContext ctx, BinaryStream s)
	{
		triangles = s.getArray!Triangle(s.get!ushort);
	}

	override uint size()
	{
		return Triangle.sizeof * triangles.length;
	}

	override void exportToObj(Stream s)
	{
		foreach (t; triangles)
			s.writefln("f %d %d %d", t.v1 + 1, t.v2 + 1, t.v3 + 1);
	}
}

class CollisionTerrainPlus : CollisionCommand
{
	TrianglePlus[] triangles;

	override void read(RomContext ctx, BinaryStream s)
	{
		triangles = s.getArray!TrianglePlus(s.get!ushort);
	}

	override uint size()
	{
		return TrianglePlus.sizeof * triangles.length;
	}	
	
	override void exportToObj(Stream s)
	{
		foreach (t; triangles)
			s.writefln("f %d %d %d", t.v1 + 1, t.v2 + 1, t.v3 + 1);
	}
}

class CollisionLoadVertices : CollisionCommand
{
	Vector3D_16[] vertices;

	override void read(RomContext ctx, BinaryStream s)
	{
		vertices = s.getArray!Vector3D_16(s.get!ushort);
	}

	override uint size()
	{
		return Vector3D_16.sizeof * vertices.length;
	}

	override void exportToObj(Stream s)
	{
		foreach (v; vertices)
			s.writefln("v %d %d %d", v.x, v.y, v.z);
	}
}

class CollisionEnd : CollisionCommand
{
	mixin(implementCommand!(
		ushort, "unknown", //0x0042 // May this be another opcode?
		// TODO CHECK
	));

	override void exportToObj(Stream s)
	{
	}

	override bool isLast()
	{
		return true;
	}
}
