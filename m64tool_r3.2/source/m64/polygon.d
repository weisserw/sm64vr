module m64.polygon;
import std.stream;
import m64.binarystream;
import m64.rom;
import m64.script;
import m64.texture;

import m64.modelexport;

/* Sources:
 * Mario 64 Hacking Doc 1.5 by VL-Tone.
 * OZMAV Map Viewer by xdaniel et al. (http://code.google.com/p/ozmav/)
 * MarioOZMAV Level Viewer sources by xdaniel.
 * Nintendo64 RDP Info Text by Michael Tedder.
 */

/// A script that defines the polygons of a level (aka. display list).
class PolygonScript : Script!PolygonCommand, IModel
{
	/* 2 commands should be used to load a texture:
	 * - PolygonSetTexture (Gives the address and format of the texture).
	 * - PolygonLoadTexture (Gives width/height/etc. about the texture).
	 *
	 * The "problem" is that sometimes there's a PolygonSetTexture, then a
	 * PolygonCall to a script that does the PolygonLoadTexture.
	 *
	 * Due to the design of this program, all ROM bank resources are just
	 * loaded once, instead of every time a reference to them is found.
	 * This is essential to handle some cycles like those found on level scripts.
	 *
	 * The point I'm trying to make is that texture loading can't be handled on
	 * afterRead(), because a script may call PolygonSetTexture, but the matching
	 * PolygonLoadTexture won't be called because PolygonCall won't reload the script.
	 *
	 * So instead, we have to make loading a 2-step process:
	 * - Load the script as usual. Textures won't be loaded on that step.
	 * - Run the scripts, just like the graphics chip would do, to load the textures.
	 */

	/// Set to true to start the 2-step texture loading process from this script.
	private bool isEntryPoint;

	this()
	{
		// This constructor is called from outside polygon scripts, so this is an entry point.
		this(true);
	}

	private this(bool isEntryPoint)
	{
		// PolygonCall calls this constructor with false.
		this.isEntryPoint = isEntryPoint;
	}

	override void read(RomContext ctx, BinaryStream s)
	{
		// Load scripts as usual (this won't load textures)
		super.read(ctx, s);

		if (isEntryPoint)
		{
			// "Interpret" the script to load the textures
			interpretLoadTextures(ctx, new RdpStatus);
		}
	}

	protected void interpretLoadTextures(RomContext ctx, RdpStatus rdp)
	{
		foreach (cmd; commands)
			cmd.interpretLoadTextures(ctx, rdp);
	}

	void exportTo(RdpStatus rdp, ModelExporter model)
	{
		foreach (cmd; commands)
			cmd.exportTo(rdp, model);
	}
}

abstract class PolygonCommand : ScriptCommand
{
	mixin(implementCommandDispatcher!(
		ubyte, PolygonCommand,
	
		0x03, PolygonMoveMem, // F3D_MOVEMEM TODO
		0x04, PolygonLoadVertices, // F3D_VTX TODO
		0x06, PolygonCall, // F3D_DL
		0xB6, PolygonClearGeometryMode, // F3D_CLEARGEOMETRYMODE
		0xB7, PolygonSetGeometryMode, // F3D_SETGEOMETRYMODE
		0xB8, PolygonReturn, // F3D_ENDDL
		0xB9, PolygonSetOtherModeLow, // F3D_SETOTHERMODE_H TODO
		0xBA, PolygonSetOtherModeHigh, // F3D_SETOTHERMODE_L TODO
		0xBB, PolygonSetTextureParams, // F3D_TEXTURE TODO
		0xBC, PolygonMoveWord, // F3D_MOVEWORD TODO
		0xBF, PolygonTriangle, // F3D_TRI1
		0xE6, PolygonLoadSync, // G_RDPLOADSYNC
		0xE7, PolygonPipeSync, // G_RDPPIPESYNC
		0xE8, PolygonTileSync, // G_RDPTILESYNC
		0xF2, PolygonSetTileSize, // G_SETTILESIZE TODO
		0xF3, PolygonLoadTexture, // G_LOADBLOCK
		0xF5, PolygonSetTile, // G_SETTILE TODO
		0xF8, PolygonSetFogColor, // G_SETFOGCOLOR
		0xFB, PolygonSetEnvColor, // G_SETENVCOLOR
		0xFC, PolygonSetCombine, // G_SETCOMBINE TODO
		0xFD, PolygonSetTexture, // G_SETTIMG
	));

	protected void interpretLoadTextures(RomContext ctx, RdpStatus rdp)
	{
	}

	void exportTo(RdpStatus rdp, ModelExporter model)
	{
		model.writeComment(format("%s", this));
	}
}

class RdpStatus
{
	/* **! TEXTURES !** */
	/// Current texture source.
	PolygonSetTexture textureSource;

	/* **! VERTEX CACHE !** */
	/// The RDP can hold 16 vertices, that can be used to make triangles.
	private RDPVertex[16] vertexCache;

	Fixed16 scaleS, scaleT;

	// int rw, rh;
	
	/// Sets a vertex in the vertex cache.
	void addVertexToCache(size_t cacheIdx, RDPVertex vertex)
	{
		vertexCache[cacheIdx] = vertex;
	}
}

class PolygonMoveMem : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, "type",
		ubyte, 0,
		ubyte, "unknown",
		SegmentAddress, "dataAddr"
	));

	RomBankResource data;

	protected override void afterRead(RomContext ctx)
	{
		// The only types used in M64 are 0x86 and 0x88
		// 0x86 = Light 0 color
		// 0x88 = Light 1 color
		// New types may be added if they're confirmed to be supported.
		if (type == 0x86 || type == 0x88)
			data = ctx.load(new RDPColor(), dataAddr);
		else
			throw new Exception("Invalid MoveMem command type.");
	}
}

class RDPColor : RomBankResource
{
	// TODO -- 8 bytes?

	ColorRGBA color;

	override void read(RomContext ctx, BinaryStream s)
	{
		color = s.get!ColorRGBA;
	}

	override uint size()
	{
		return ColorRGBA.sizeof;
	}
}

class PolygonLoadVertices : PolygonCommand
{
	// TODO lacking implementCommand bitfields
	mixin(implementCommand!(
		ubyte, "nAndCacheIdx",
		ushort, "nBytes",
		SegmentAddress, "verticesAddr"
	));

	RDPVertexList vertexList;

	private int cacheStartIdx()
	{
		return nAndCacheIdx & 0x0F;
	}

	private int vertexCount()
	{
		return (nAndCacheIdx >> 4) + 1;
	}

	protected override void afterRead(RomContext ctx)
	{
		int n = vertexCount();
		enforce(nBytes ==  n * 0x10, "Polygon vertex: Unexpected byte count.");
		vertexList = ctx.load(new RDPVertexList(n), verticesAddr);
	}

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		int startIdx = cacheStartIdx();
		int n = vertexCount();

		for (int i = 0; i < n; i++)
		{
			RDPVertex v = vertexList.vertices[i];

			ModelVertex mv;

			mv.x = v.x;
			mv.y = v.y;
			mv.z = v.z;

			if (rdp.textureSource !is null) // TODO is this OK or caused by a bug?
			{
				mv.u = v.s * rdp.scaleS.floating() / 32 / rdp.textureSource.tex.width; // TODO check
				mv.v = v.t * rdp.scaleT.floating() / 32 / rdp.textureSource.tex.height; // TODO check
			}
			else
			{
				mv.u = 0.0;
				mv.v = 0.0;
				// writeln("notex"); TODO XXX
			}

			rdp.addVertexToCache(startIdx + i, v);
			model.addVertexToCache(startIdx + i, mv);
		}
	}
}

/// A list of vertices in the RDP.
class RDPVertexList : RomBankResource
{
	// TODO: Overflows a LOT, but a lot of times it also fits perfectly... what's going on?

	/// The vertices.
	RDPVertex[] vertices;

	/// Create a new and empty vertex list.
	this() { }

	/// Create a vertex list with the specified number of vertices.
	/// (This is [more or less] a hack to get read() working).
	private this(size_t count)
	{
		vertices.length = count;
	}

	override void read(RomContext ctx, BinaryStream s)
	{
		vertices = s.getArray!RDPVertex(vertices.length);
	}

	override uint size()
	{
		return RDPVertex.sizeof * vertices.length;
	}
}

/// A vertex in the RDP format.
struct RDPVertex
{
	/// X coordinate.
	short x;
	/// Y coordinate.
	short y;
	/// Z coordinate.
	short z;
	/// W coordinate.
	short w;

	/// S coordinate (textures).
	short s;
	/// T coordinate (textures).
	short t;

	/// Vertex color.
	ColorRGBA color;
}

class PolygonCall : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, "pushReturnAddress",
		ushort, 0,
		SegmentAddress, "jumpAddr"
	));

	PolygonScript jump;

	protected override void afterRead(RomContext ctx)
	{
		// See PolygonScript for more details about this constructor.
		jump = ctx.load(new PolygonScript(false), jumpAddr);
	}

	override bool isLast()
	{
		if (pushReturnAddress == 1)
			return true; // Jump
		else
			return false; // Call
	}

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		jump.exportTo(rdp, model);
	}

	protected override void interpretLoadTextures(RomContext ctx, RdpStatus rdp)
	{
		jump.interpretLoadTextures(ctx, rdp);
	}
}

/* Geometry modes (not complete or necessarily correct):
 * 0x00000001 - Z Buffering
 * 0x00000002 - Enable textures
 * 0x00000200 - Smooth shading
 * 0x00001000 - Front face culling
 * 0x00002000 - Back face culling
 * 0x00010000 - Fog
 * 0x00020000 - Lightning
 */

/// Disables the specified geometry modes.
class PolygonClearGeometryMode : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, "mode"
	));
}

/// Enables the specified geometry modes.
class PolygonSetGeometryMode : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, "mode"
	));
}

class PolygonReturn : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0
	));

	override bool isLast()
	{
		return true;
	}
}

/* Next commands just set some mode flags. Nothing too important.
 * They take "numBits" bits starting after "idxBits",
 * and replace those bits in the original flags with touse in "value". */

class PolygonSetOtherModeLow : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "idxBits",
		ubyte, "numBits",
		uint, "value"
	));
}


class PolygonSetOtherModeHigh : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, "idxBits",
		ubyte, "numBits",
		uint, "value"
	));
}

/// A 16-bit fixed point number.
struct Fixed16
{
	/// Fixed point representation of the number.
	ushort fixed;
	
	/// Create a Fixed16 from the fixed point representation of the number.
	this(ushort fixed)
	{
		this.fixed = fixed;
	}

	/// Create a Fixed16 from the floating point representation of the number
	this(float floating)
	{
		this.floating = floating;
	}

	/// Get a floating point representation of the number.
	@property float floating()
	{
		return cast(float)fixed / 65535.0f;
	}

	/// Set the number from a floating point representation. 
	@property void floating(float value)
	{
		fixed = cast(ushort)(value * 65535.0f);
	}

	string toString()
	{
		return format("%f", floating());
	}
}

class PolygonSetTextureParams : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, "unknown",

		// From OZMAV, seems to work fine...
		Fixed16, "scaleS",
		Fixed16, "scaleT"
	));

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		rdp.scaleS = scaleS;
		rdp.scaleT = scaleT;
	}
}

class PolygonMoveWord : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, "TODO1",
		ushort, "TODO2",
		uint, "TODO3"
	));

	/*
	override void afterRead(RomContext ctx)
	{
		writefln("%.2X %.4X %.8X", TODO1, TODO2, TODO3);
		readln();
	}
	*/
}

class PolygonTriangle : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		ubyte, 0,
		ubyte, "v1Offset", // v1Idx = v1Offset / 10
		ubyte, "v2Offset", // v2Idx = v2Offset / 10
		ubyte, "v3Offset"  // v3Idx = v3Offset / 10
	));

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		int v1 = v1Offset / 10;
		int v2 = v2Offset / 10;
		int v3 = v3Offset / 10;
		
		model.createFace(v1, v2, v3);
	}
}

class PolygonLoadSync : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0
	));
}

class PolygonPipeSync : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0
	));
}

class PolygonTileSync : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0
	));
}

struct Coord2_12_12
{
	private ubyte xx;
	private ubyte xy;
	private ubyte yy;

	@property ushort x()
	{
		return ((xx << 4) | (xy >> 4)) & 0xFFF;
	}

	@property ushort y()
	{
		return ((xy << 8) | yy) & 0xFFF;
	}
}

class PolygonSetTileSize : PolygonCommand
{
	mixin(implementCommand!(
		Coord2_12_12, "lowST",
		ubyte, "tile",
		Coord2_12_12, "highST"
	));


	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		//rdp.rw = (highST.x - lowST.x) / 4 + 1;
		//rdp.rh = (highST.y - lowST.y) / 4 + 1;
	}
}

class PolygonLoadTexture : PolygonCommand
{
	mixin(implementCommand!( // TODO
		ubyte, 0,
		ushort, 0,
		ubyte, "tile",

		// Need bitfields
		Coord2_12_12, "dims"
	)); 

	protected override void interpretLoadTextures(RomContext ctx, RdpStatus rdp)
	{
		if (rdp.textureSource is null)
			throw new Exception("NO SOURCE PolygonLoadTexture!");

		// Extract width and height and load the texture
		int w = 0x2000 / dims.y;
		int h = (dims.x + 1) / w;

		rdp.textureSource.doLoadTexture(ctx, w, h);

		rdp.textureSource = null;
	}
}

class PolygonSetTile : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1",
		ubyte, "unknown2",
		ubyte, 0,
		SegmentAddress, "unkAddr" // NOT SURE; SHOULD CHECK; PROBABLY NOT; TODO
	));

	/*
	protected override void afterRead(RomContext ctx)
	{
		writeln(unknown1);
		writeln(unknown2);
		writeln(unkAddr);
		readln();
	}
	*/
}

class PolygonSetFogColor : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		ColorRGBA, "color"
	));
}

class PolygonSetEnvColor : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		ColorRGBA, "color"
	));
}

class PolygonSetCombine : PolygonCommand
{
	mixin(implementCommand!( // TODO
		ubyte, "TODO1",
		ushort, "TODO2",
		uint, "TODO3"
	));
}

class PolygonSetTexture : PolygonCommand
{
	mixin(implementCommand!(
		ubyte, "pixelFormat",
		ushort, 0,
		SegmentAddress, "texAddr"
	));

	Texture tex;

	protected override void interpretLoadTextures(RomContext ctx, RdpStatus rdp)
	{
		if (rdp.textureSource !is null)
			throw new Exception("SOURCE NOT CONSUMED PolygonSetTexture!");
	
		rdp.textureSource = this;
	}

	private void doLoadTexture(RomContext ctx, int width, int height)
	{
		tex = ctx.load(new Texture(safeCast!TextureFormat(pixelFormat), width, height), texAddr);
	}

	override void exportTo(RdpStatus rdp, ModelExporter model)
	{
		model.selectTexture(tex);

		// Save a reference to this instance to RDP (required later for texture coords)
		rdp.textureSource = this;
	}
}
