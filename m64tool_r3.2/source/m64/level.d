module m64.level;

import std.stdio;
import std.string;
import std.bitmanip;
import std.file;
import std.math;
import std.path;
import m64.binarystream;
import m64.rom;
import m64.script;
import m64.geometry;
import m64.polygon;
import m64.behaviour;
import m64.collision;
import m64.modelexport;

private void tryMkdir(string dirName)
{
	try { mkdir(dirName); } catch (Exception ex) { }
}

public class LevelExporterContext
{
	private Rom rom;

	private string outputPath;
	private int currentLevel;

	private ObjExporter currentLevelExporter;
	private int currentLevelObject;
	private RdpStatus rdp;

	/// ID to model associateve array.
	private IModel[ubyte] modelIds;

	/**
	 * Creates a new LevelExporterContext.
	 *
	 * Params:
	 * 		outputPath = Path where the levels should be exported.
	 */
	this(Rom rom, string outputPath)
	{
		this.rom = rom;
		this.outputPath = outputPath;
		this.currentLevel = 0;
		tryMkdir(outputPath);
	}

	~this()
	{
		// Make sure that we don't leave any file open
		if (currentLevelExporter !is null)
			currentLevelExporter.close();
	}

	/**
	 * Starts a new level area.
	 */
	void startLevel()
	{
		if (currentLevelExporter !is null)
		{
			writeln("WARNING: Called startLevel() without a previous endLevel().");
			endLevel();
		}

		string levelOutputPath = buildPath(
			outputPath,
			format("%d", currentLevel++)
		);

		tryMkdir(levelOutputPath);

		currentLevelExporter = new ObjExporter(levelOutputPath);
		currentLevelObject = 0;
		rdp = new RdpStatus;
	}

	/**
	 * Inserts a model in the current level area.
	 *
	 * Params:
	 * 		model = The model to insert.
	 */
	void putModel(IModel model)
	{
		if (currentLevelExporter is null)
		{
			writeln("WARNING: Called putModel() outside of level area.");
			return;
		}
		currentLevelExporter.createObject(format("%d", currentLevelObject++));
		model.exportTo(rdp, currentLevelExporter);
	}

	/**
	 * Inserts a model in the current level area (using a previously defined ID).
	 *
	 * Params:
	 * 		id = The ID of the model to insert.
	 * 		pos = The position of the model in the level.
	 * 		rot = The rotation of the model in the level, in degrees.
	 */
	void putModel(ubyte id, Vector3D_16 pos, Vector3D_16 rot)
	{
		/*
		if (id == 0) // TODO
		{
			currentLevelExporter.writeComment(format("Model 0 is in %d %d %d", position.x, position.y, position.z));
			return;
		}
		*/

		if (!(id in modelIds))
		{
			writefln("WARNING: Model with ID=%d NOT FOUND!", id);
			return;
		}

		double tX = pos.x, tY = pos.y, tZ = pos.z;
		double rX = degToRad(rot.x), rY = degToRad(rot.y), rZ = degToRad(rot.z);

		currentLevelExporter.addTranslation(tX, tY, tZ);
		currentLevelExporter.addRotation(rX, rY, rZ);
		putModel(modelIds[id]);
		currentLevelExporter.addRotation(-rX, -rY, -rZ);
		currentLevelExporter.addTranslation(-tX, -tY, -tZ);
	}
	
	private double degToRad(double x)
	{
		return x * PI / 180.0;
	}

	/**
	 * Associates a identifier with a model, which can be later inserted by ID.
	 *
	 * Params:
	 * 		id = The ID to associate to the model.
	 * 		model = The model.
	 */
	void setModelId(ubyte id, IModel model)
	{
		modelIds[id] = model;
	}

	/**
	 * Ends a level area.
	 */
	void endLevel()
	{
		if (currentLevelExporter is null)
		{
			writeln("WARNING: Called endLevel() without a previous startLevel().");
			return;
		}

		currentLevelExporter.close();
		currentLevelExporter = null;
	}
}

/// A level script (or more precisely, a branch of a level script).
class LevelScript : Script!LevelCommand
{
	void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		// Check if we've entered in an infinite loop
		foreach (script; callStack)
		{
			if (script == this)
			{
				// We've entered a infinite loop, kill this branch
				return;
			}
		}

		// Add ourselves to the callstack
		callStack ~= this;

		foreach (cmd; commands)
			cmd.exportLevels(ctx, callStack);
	}
}

abstract class LevelCommand : ScriptCommand
{
	mixin(implementCommandDispatcher!(
		ushort, LevelCommand,
	
		0x0010, LevelLoadAndCall,
		0x0110, LevelLoadAndJump,
		0x0204, LevelEnd,
		0x0304, Level03,
		0x0404, Level04,
		0x0508, LevelJump,
		0x0608, LevelCall,
		0x0704, LevelReturn,
		0x0A04, Level0A,
		0x0B08, Level0B,
		0x0C0C, LevelConditionalJump,
		0x1108, Level11,
		0x1208, Level12,
		0x1304, Level13,
		0x1610, LevelLoadRAM,
		0x170C, LevelLoadBank,
		0x180C, LevelLoadMIO0Bank,
		0x1904, Level19,
		0x1A0C, LevelLoadTexBank,
		0x1B04, LevelStartRAMLoad,
		0x1C04, Level1C,
		0x1D04, LevelEndRAMLoad,
		0x1E04, Level1E,
		0x1F08, LevelStartArea,
		0x2004, LevelEndArea,
		0x2108, LevelLoadPolygon,
		0x2208, LevelLoadGeometry,
		0x2418, LevelInsertObject,
		0x250C, LevelLoadMario,
		0x2608, LevelLinkWarp,
		0x2708, LevelLinkPainting,
		0x280C, Level28,
		0x2904, Level29,
		0x2A04, Level2A,
		0x2B0C, Level2B,
		0x2E08, LevelLoadCollision,
		0x2F08, Level2F,
		0x3004, Level30,
		0x3104, LevelSetTerrainBehaviour,
		0x3308, Level33,
		0x3404, Level34,
		0x3608, LevelSetMusic,
		0x3704, Level37,
		0x3804, Level38,
		0x3908, LevelInsertMultipleObjects,
		0x3B0C, Level3B,
		0x3C04, Level3C,
	));

	void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
	}
}

class LevelLoadAndCall : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		Segment, "destination",
		RomChunk, "sourceChunk",
		SegmentAddress, "jumpAddr"
	));

	RomBank source;
	LevelScript jump;

	protected override void afterRead(RomContext ctx)
	{
		source = ctx.loadBank(destination, sourceChunk, false);
		jump = ctx.load(new LevelScript, jumpAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		jump.exportLevels(ctx, callStack.dup);
	}
}

class LevelLoadAndJump : LevelLoadAndCall
{
	override bool isLast()
	{
		return true;
	}
}

class LevelEnd : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0
	));
	
	override bool isLast()
	{
		return true;
	}
}

class Level03 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown"
	));
}

class Level04 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, 1
	));
}

class LevelJump : LevelCall
{	
	override bool isLast()
	{
		return true;
	}
}

class LevelCall : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0,
		SegmentAddress, "jumpAddr"
	));

	LevelScript jump;

	protected override void afterRead(RomContext ctx)
	{
		jump = ctx.load(new LevelScript, jumpAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		jump.exportLevels(ctx, callStack.dup);
	}
}

class LevelReturn : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0
	));
	
	override bool isLast()
	{
		return true;
	}
}

class Level0A : LevelCommand
{
	// Only used onceu
	mixin(implementCommand!(
		ushort, 0
	));

	// TODO does this command end the script? (check overlaps)
}

class Level0B : LevelCommand
{
	// Only used once
	mixin(implementCommand!(
		ubyte, 4,
		ubyte, 0,
		uint, 0
	));
}

class LevelConditionalJump : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0x0200,
		int, "value",
		SegmentAddress, "jumpAddr"
	));

	LevelScript jump;
	
	protected override void afterRead(RomContext ctx)
	{
		jump = ctx.load(new LevelScript, jumpAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		jump.exportLevels(ctx, callStack.dup);
	}
}

class Level11 : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0,
		uint, "ramAddr"
	));
}

class Level12 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown",
		uint, "ramAddr"
	));
}

class Level13 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown",
	));
}

class LevelLoadRAM : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0,
		uint, "destinationRamAddr", // (RAM address)
		RomChunk, "sourceChunk"
	));
}

class LevelLoadBank : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		Segment, "destination",
		RomChunk, "sourceChunk"
	));

	RomBank bank;

	protected override void afterRead(RomContext ctx)
	{
		bank = ctx.loadBank(destination, sourceChunk, false);
	}
}

class LevelLoadMIO0Bank : LevelLoadBank
{	
	protected override void afterRead(RomContext ctx)
	{
		bank = ctx.loadBank(destination, sourceChunk, true);
	}
}

class Level19 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown"
	));
}

class LevelLoadTexBank : LevelLoadMIO0Bank
{
}

class LevelStartRAMLoad : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0
	));
}

class Level1C : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0
	));
}

class LevelEndRAMLoad : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0
	));
}

class Level1E : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0
	));
}

class LevelStartArea : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "area",
		ubyte, 0,
		SegmentAddress, "geomAddr"
	));

	GeometryLayout geom;

	protected override void afterRead(RomContext ctx)
	{
		geom = ctx.load(new GeometryLayout, geomAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		ctx.startLevel();
		ctx.putModel(geom);
	}
}

class LevelEndArea : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0
	));

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		ctx.endLevel();
	}
}

class LevelLoadPolygon : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "unknown", // Flags?
		ubyte, "id",
		SegmentAddress, "polygonsAddr"
	));

	PolygonScript polygons;

	protected override void afterRead(RomContext ctx)
	{
		polygons = ctx.load(new PolygonScript, polygonsAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		ctx.setModelId(id, polygons);
	}
}

class LevelLoadGeometry : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "id",
		SegmentAddress, "geometryAddr"
	));

	GeometryLayout geometry;
	
	protected override void afterRead(RomContext ctx)
	{
		geometry = ctx.load(new GeometryLayout, geometryAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		ctx.setModelId(id, geometry);
	}
}

class LevelInsertObject : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "courses", // Binary value (should create bitfields?)
		ubyte, "id",
		Vector3D_16, "position",
		Vector3D_16, "rotation", // In degrees
		uint, "behaviourParam",
		SegmentAddress, "behaviourAddr"
	));

	BehaviourScript behaviour;

	protected override void afterRead(RomContext ctx)
	{
		behaviour = ctx.load(new BehaviourScript, behaviourAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		ctx.putModel(id, position, rotation);
	}
}

class LevelLoadMario : LevelCommand
{
	mixin(implementCommand!(
		ushort, 1,
		uint, 1,
		SegmentAddress, "marioBehaviourAddr"
	));

	BehaviourScript marioBehaviour;

	protected override void afterRead(RomContext ctx)
	{
		marioBehaviour = ctx.load(new BehaviourScript, marioBehaviourAddr);
	}
}

class LevelLinkWarp : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "sourceWarp",
		ubyte, "destinationId",
		ubyte, "destinationArea",
		ubyte, "destinationWarp",
		ubyte, "unknown", // Sometimes 0x80, flag?
		ubyte, 0
	));
}

class LevelLinkPainting : LevelLinkWarp
{
}

class Level28 : LevelCommand
{
	// I just have no idea about this command, it makes no sense to me
	mixin(implementCommand!(
		ubyte, "unknown1",
		ubyte, "unknown2",
		ubyte, "unknown3",
		ubyte, 0,
		ubyte, "unknown4",
		ubyte, "unknown5",
		ubyte, "unknown6",
		ubyte, "unknown7",
		ushort, "unknown8"
	));
}

class Level29 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "unknown",
		ubyte, 0
	));
}

class Level2A : LevelCommand
{
	// This instruction is used just once
	mixin(implementCommand!(
		ubyte, 1,
		ubyte, 0
	));
}

class Level2B : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 1,
		ubyte, 0,
		ushort, "unknown1",
		Vector3D_16, "unknown2"
	));
}

class LevelLoadCollision : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0,
		SegmentAddress, "collisionAddr"
	));

	CollisionData collision;

	protected override void afterRead(RomContext ctx)
	{
		collision = ctx.load(new CollisionData, collisionAddr);

		/*
		string objName = format("%.2X_%.6X.obj", collisionAddr.segment, collisionAddr.offset);
		Stream obj = new std.stream.File(objName, FileMode.OutNew);
		collision.exportToObj(obj);
		*/
	}
}

class Level2F : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0,
		SegmentAddress, "somethingAddr"
	));

	protected override void afterRead(RomContext ctx)
	{
		//writeln(ctx.getSomeData(somethingAddr));
		//readln();
		// TODO what to load?
		ctx.load(new Level2FUnknownResource, somethingAddr);
	}
}

class Level2FUnknownResource : RomBankResource
{
	override void read(RomContext ctx, BinaryStream s)
	{
		//writeln(s.getSomeData());
	}

	override uint size()
	{
		return 0;
	}
}

class Level30 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown"
	));
}

class LevelSetTerrainBehaviour : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "behaviour"
	));
}

class Level33 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1", // 0x00, 0x01 or 0x08. Flags?
		ubyte, "unknown2",
		uint, "unknown3", // 0xFFFFFF00 or 0x00000000.
	));
}

class Level34 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "unknown",
		ubyte, 0
	));
}

class LevelSetMusic : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown", // Music param?
		ubyte, 0,
		ubyte, "id",
		ushort, 0
	));
}

class Level37 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "unknown"
	));
}

class Level38 : LevelCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, 0xBE
	));
}

class LevelInsertMultipleObjects : LevelCommand
{
	mixin(implementCommand!(
		ushort, 0,
		SegmentAddress, "objectsAddr"
	));

	MultipleObjectList objects;

	protected override void afterRead(RomContext ctx)
	{
		objects = ctx.load(new MultipleObjectList, objectsAddr);
	}

	override void exportLevels(LevelExporterContext ctx, LevelScript[] callStack)
	{
		foreach (i; objects.items)
		{
			Vector3D_16 rot;
			rot.x = i.horizontalRotation;
			rot.y = 0;
			rot.z = 0;

			ctx.putModel(ctx.rom.presets[i.preset - 0x1F].id, i.position, rot);
		}
	}
}

class MultipleObjectList : RomBankResource
{
	MultipleObjectListItem[] items;

	override void read(RomContext ctx, BinaryStream s)
	{
		while (true)
		{
			ushort tmp = s.get!short;
			ushort preset = cast(ushort)(tmp & 0x1FF);
			ubyte horizontalRotation = cast(ubyte)(tmp >> 9);

			if (preset == 0x00)
				throw new Exception("Preset 0x00 (level command 0x39).");

			if (preset == 0x1E)
			{
				enforce(horizontalRotation == 0, "Preset 0x1E with horizontalRotation != 0");
				break;
			}

			MultipleObjectListItem o;
			o.preset = preset;
			o.horizontalRotation = horizontalRotation;
			o.position = s.get!Vector3D_16;
			o.behaviourParams = s.get!ushort;
			items ~= o;
		}	
	}

	override uint size()
	{
		return MultipleObjectListItem.sizeof * items.length + 2 /* Last */;
	}
}

struct MultipleObjectListItem
{
	// Bitfields start from the least significant bit, so order is reversed.
	// (I.e. Stored as HHHHHHHP PPPPPPPP, H = h. rotation and P = preset).
	mixin(bitfields!(
		ushort, "preset", 9,
		ubyte, "horizontalRotation", 7
	));

	Vector3D_16 position;
	ushort behaviourParams; // Overrides params defined in preset
}

struct ModelPreset
{
	SegmentAddress behaviourAddr;
	ubyte id;
	ushort behaviourParam;

	void read(RomContext ctx, BinaryStream s)
	{
		behaviourAddr = s.get!SegmentAddress;
		enforce(s.get!ubyte == 0, "ModelPreset[4] != 0.");
		id = s.get!ubyte;
		behaviourParam = s.get!ushort;

		/* We can't load the behaviour script here easily,
		 * because the banks that it uses may have been reassigned.
		 *
		 * It's only actually possible to use this address at runtime.
		 * (Or hardcoding everything, which is ugly...)
		 */
	}
}


class Level3B : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1",
		ubyte, "unknown2",
		short, "unknown3",
		short, "unknown4",
		short, "unknown5",
		short, "unknown6"
	));
}

class Level3C : LevelCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1",
		ubyte, "unknown2"
	));
}
