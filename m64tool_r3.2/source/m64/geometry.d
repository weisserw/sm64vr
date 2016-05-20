module m64.geometry;
import m64.binarystream;
import m64.rom;
import m64.script;
import m64.polygon;

import m64.modelexport;

class GeometryLayout : Script!GeometryCommand, IModel
{
	void exportTo(RdpStatus rdp, ModelExporter model)
	{
		foreach (cmd; commands)
			cmd.exportTo(rdp, model);
	}
}

abstract class GeometryCommand : ScriptCommand
{
	mixin(implementCommandDispatcher!(
		ubyte, GeometryCommand,

		0x00, Geometry00,
		0x01, GeometryEnd,
		0x02, GeometryCall,
		0x03, GeometryReturn,
		0x04, GeometryStartNode,
		0x05, GeometryEndNode,
		0x07, Geometry07,
		0x08, Geometry08,
		0x09, Geometry09,
		0x0A, Geometry0A,
		0x0B, Geometry0B,
		0x0C, Geometry0C,
		0x0D, Geometry0D,
		0x0E, Geometry0E,
		0x0F, Geometry0F,
		0x10, Geometry10,
		0x11, Geometry11,
		0x12, Geometry12,
		0x13, GeometryLoadPolygon,
		0x14, Geometry14,
		0x15, GeometryLoadPolygon2,
		0x16, GeometryShadow,
		0x17, Geometry17,
		0x18, GeometryWeather,
		0x19, GeometryBackground,
		0x1C, Geometry1C,
		0x1D, GeometryScale,
		0x20, GeometryDrawingDistance,
	));

	void exportTo(RdpStatus rdp, ModelExporter model)
	{
		model.writeComment(format("%s", this));
	}
}

class Geometry00 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		SegmentAddress, "jumpAddr"
	));

	GeometryLayout jump;

	protected override void afterRead(RomContext ctx)
	{
		jump = ctx.load(new GeometryLayout, jumpAddr);
	}

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		jump.exportTo(rdp, model);
	}

	// TODO: Does this end the script? (is it a jump?)
}

class GeometryEnd : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));

	override bool isLast()
	{
		return true;
	}
}

class GeometryCall : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 1, // ???
		ushort, 0,
		SegmentAddress, "jumpAddr"
	));

	GeometryLayout jump;

	protected override void afterRead(RomContext ctx)
	{
		jump = ctx.load(new GeometryLayout, jumpAddr);
	}

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		jump.exportTo(rdp, model);
	}
}

class GeometryReturn : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1", // Mostly 0
		ushort, "unknown2" // Mostly 0
	));

	override bool isLast()
	{
		return true;
	}
}

class GeometryStartNode : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

class GeometryEndNode : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

class Geometry07 : GeometryCommand
{
	mixin(implementCommand!(
		// TODO document a bit
		ubyte, 0,
		ubyte, "unknown1", // Id?
		ubyte, "unknown2",
		ushort, "unknown3",
		short, "unknown4", // Percent?
		ushort, "unknown5", // Percent?
		ushort, 0
	));

	/*
	protected override void afterRead(RomContext ctx)
	{
		writefln("%d %d %d %d %d", unknown1, unknown2, unknown3, unknown4, unknown5);
	}
	*/
}

class Geometry08 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, 0,
		ubyte, "unknown",
		uint, 0x00A00078, // ???
		uint, 0x00A00078 // ???
	));
}

class Geometry09 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, 0,
		ubyte, 0x64
	));
}

class Geometry0A : GeometryCommand
{
	// TODO
	mixin(implementCommand!(
		ubyte, "unknown1",
		ubyte, "unknown2",
		ubyte, "unknown3",
		ubyte, "unknown4",
		ubyte, "unknown5",
		ubyte, "unknown6",
		ubyte, "unknown7",
		ubyte, "unknown8",
		ubyte, "unknown9",
		ubyte, "unknown10",
		ubyte, "unknown11"
	));

	protected override void afterRead(RomContext ctx)
	{
		/*
		writefln("%.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X",
			unknown1, unknown2, unknown3, unknown4, unknown5,
			unknown6, unknown7, unknown8, unknown9, unknown10,
			unknown11
		);
		*/
	}
}

class Geometry0B : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

class Geometry0C : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, "unknown", // 0 or 1 (boolean?)
		ushort, 0
	));
}

import std.stdio;

class Geometry0D : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		short, "unknown1", // Sometimes multiple of 10/50/100, sometimes power of 2
		short, "unknown2" // Ditto
	));
	
	/*
	protected override void afterRead(RomContext ctx)
	{
		writefln("%d %d",
			unknown1, unknown2
		);
	}
	*/
}

class Geometry0E : GeometryCommand
{
	mixin(implementCommand!(
		ushort, 0,
		ubyte, "numFrames",
		uint, "ramAddress"
	));
}

class Geometry0F : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, 0,
		ubyte, "unknown1",
		ushort, 0,
		short, "unknown2", // Commonly multiple of 100
		short, "unknown3", // Commonly multiple of 100

		// Those 2 bytes may form a short...
		byte, "unknown4",
		ubyte, 0,

		short, "unknown5", // Commonly multiple of 100
		short, "unknown6", // Commonly multiple of 100
		uint, "ramAddress" // Or zero
	));
	
	/*
	protected override void afterRead(RomContext ctx)
	{
		writefln("%.2X %d %d %.2X 00 %d %d %.8X",
			unknown1, unknown2, unknown3, unknown4, unknown5,
			unknown6, ramAddress
		);
	}
	*/
}

class Geometry10 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1", // 0x00 or 0x81
		ushort, 0,
		short, "unknown2",
		short, "unknown3",
		short, "unknown4",
		short, "unknown5", // Looks like an angle (rotation X?)
		short, "unknown6", // Looks like an angle (rotation Y?)
		short, "unknown7", // Looks like an angle (rotation Z?)
	));
	
	/*
	protected override void afterRead(RomContext ctx)
	{
		writefln("%.2X 0000 %d %d %d %d %d %d",
			unknown1, unknown2, unknown3, unknown4, unknown5,
			unknown6, unknown7
		);
	}
	*/
}

class Geometry11 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1", // 0x00 or 0x81
		short, "unknown2",
		short, "unknown3",
		short, "unknown4"
	));
	
	/*
	protected override void afterRead(RomContext ctx)
	{
		writefln("%.2X %d %d %d",
			unknown1, unknown2, unknown3, unknown4
		);
	}
	*/
}

class Geometry12 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0
	));
}

class GeometryLoadPolygon : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, "drawingLayer",
		Vector3D_16, "position",
		SegmentAddress, "polygonsAddr"
	));

	PolygonScript polygons;  // Can be null for an invisible joint (for animation)

	protected override void afterRead(RomContext ctx)
	{
		polygons = !polygonsAddr.isNull ? ctx.load(new PolygonScript, polygonsAddr) : null;
	}

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		if (polygons !is null)
		{
			model.addTranslation(position.x, position.y, position.z);
			polygons.exportTo(rdp, model);
			model.addTranslation(-position.x, -position.y, -position.z);
		}
	}
}

class Geometry14 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0
	));
}

class GeometryLoadPolygon2 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, "drawingLayer",
		ushort, 0,
		SegmentAddress, "polygonsAddr"
	));

	PolygonScript polygons; // Can be null for an invisible joint (for animation)

	protected override void afterRead(RomContext ctx)
	{
		polygons = !polygonsAddr.isNull ? ctx.load(new PolygonScript, polygonsAddr) : null;
	}

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		if (polygons !is null)
			polygons.exportTo(rdp,model);
	}
}

class GeometryShadow : GeometryCommand
{
	mixin(implementCommand!(
		ushort, 0,
		ubyte, "shape", // 0x63 = Round
		ushort, "transparency",
		ushort, "shadow_size"
	));
}

class Geometry17 : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

class GeometryWeather : GeometryCommand
{
	/* http://jul.rustedlogic.net/thread.php?id=2794
	 * 
	 * Weather types by messiaen:
	 * 01 = used in Cool Cool Mountain (area 1) and Snowman's Land (area 1). Produces the snow effect. 
	 * 02 = used in Jolly Roger Bay (area 2) and Secret Aquarium. 
	 * 0C = used in Lethal Lava Land (area 1), Bowser's Fire Sea and Bowser Second Battle 
	 * 0D = used in Dire Dire Docks (area 1). 
	 * 0E = used in Jolly Roger Bay and Dire Dire Docks (area 2).
	 */
	mixin(implementCommand!(
		ubyte, 0,
		ushort, "weather",
		uint, "ramAddress"
	));
}

class GeometryBackground : GeometryCommand
{
	// TODO figure out how it works
	// http://jul.rustedlogic.net/thread.php?id=1880&page=2

	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown1",
		ubyte, "unknown2",
		uint, "ramAddress" // Or zero
	));

	/*
	protected override void afterRead(RomContext ctx)
	{
		writefln("%.2X %.2X %.8X", unknown1, unknown2, ramAddress);
	}
	*/
}

class Geometry1C : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0,
		uint, "ramAddress"
	));
}

class GeometryScale : GeometryCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, "scaleFactor"  // 0x4000 = Normal, 0x2000 = Half, 0x8000 = Twice, etc.
	));
}

class GeometryDrawingDistance : GeometryCommand
{
	// According to http://jul.rustedlogic.net/thread.php?id=1880&page=2
	mixin(implementCommand!(
		ubyte, 0,
		ushort, "drawingDistance"
	));
}
