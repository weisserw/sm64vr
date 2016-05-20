module m64.rom;
import std.stdio;
import std.string;
import std.stream;
import std.system;
import std.file;
import std.path;
import std.exception;
import std.bitmanip;
import m64.binarystream;
import m64.mio0;
import m64.script;
import m64.level;

/* Special thanks to:
 * - messiaen, for telling me about Nagra's doc.
 * - Nagra, for helping me get the addresses of the hardcoded banks/scripts.
 */

/* A brief explanation of the ROM structure
 * ----------------------------------------
 * To use resources, the game needs to load them in memory, and loading all of
 * them at the same time is not possible (not enough memory, loading time, etc.).
 * Resources are loaded when they are required.
 * 
 * Instead of loading each resource individually, the game loads block of resources
 * (e.g. all textures of a specific level). We call those blocks "ROM banks".
 *
 * When ROM banks are loaded, they are assigned an identifier, called "segment".
 *
 * To refer to resources inside a ROM bank, a "segment address" is used. It contains:
 * - The segment specifying which ROM bank contains the resource.
 * - The position in the ROM bank where the resource is located.
 *
 * ROM banks are loaded from "Level Scripts".
 * Resources are loaded from almost everywhere, mostly scripts.
 */

/**
 * A Mario 64 ROM.
 * The most interesting zone of the ROM are the ROM banks, which contains almost all resource data.
 */
class Rom
{
	/// Stream containing the ROM.
	private BinaryStream s;

	/// Map of ROM banks.
	RomBank[RomChunk] banks;

	/// Bank whose address is hardcoded and contains the entry point script.
	RomBank entryBank;

	/// Bank whose address is hardcoded and contains some resources.
	RomBank commonBank;

	/// Level script whose address is hardcoded and is the entry point.
	LevelScript entryScript;

	/**
	 * Preset models (for level script 0x39 command).
	 * The preset IDs start at 0x1F.
	 */
	ModelPreset[366] presets;
	
	/**
	 * Read and parse the specified Mario 64 ROM.
	 * Params:
	 * 	s = Stream containing the ROM.
	 */
	this(Stream s)
	{
		this.s = new BinaryStream(s, Endian.bigEndian);
		loadAllBanks();
	}

	void loadAllBanks()
	{
		// Get the addresses of the main banks from the ROM (0x80248AA4)
		int entryStart = mipsGet32(0x3AA6, 0x3AB2);
		int entryEnd = mipsGet32(0x3AAA, 0x3AAE);
		ubyte entrySegment = safeCast!ubyte(mipsGet16(0x3AB6));

		int bankStart = mipsGet32(0x3AC2, 0x3ACE);
		int bankEnd = mipsGet32(0x3AC6, 0x3ACA);
		ubyte bankSegment = safeCast!ubyte(mipsGet16(0x3AD6));

		//int entryAddr = mipsGet32(0x3B36, 0x3B3E);

		// Load the main banks and jump to the entry point
		// This will load most banks, resources, etc.
		RomContext ctx = new RomContext(this);
		entryBank = ctx.loadBank(entrySegment, RomChunk(entryStart, entryEnd), false);
		commonBank = ctx.loadBank(bankSegment, RomChunk(bankStart, bankEnd), true);
		entryScript = ctx.load(new LevelScript, SegmentAddress(entrySegment, 0));

		// Load the preset model list
		s.position = 0xEC7E0;
		foreach (i, ref p; presets)
			p.read(ctx, s);
	}

	/**
	 * Gets a 32-bit integer loaded with the typical MIPS method (LUI + ADDIU).
	 * Params:
	 * 	offsetHi = Offset of the high part (LUI + 2).
	 * 	offsetLo = Offset of the low part (ADDIU + 2).
	 * Returns: The 32-bit integer.
	 */
	int mipsGet32(ulong offsetHi, ulong offsetLo)
	{
		return ((mipsGet16(offsetHi) << 16) + mipsGet16(offsetLo));
	}

	/**
	 * Gets a 16-bit integer from the specified offset.
	 * Params:
	 * 	offset = Offset of the integer (INSTR + 2).
	 * Returns: The 16-bit integer.
	 */
	int mipsGet16(ulong offset)
	{
		s.position = offset;
		return s.get!short;
	}
		
	
	/**
	 * Load a ROM bank from the specified ROM chunk.
	 * Params:
	 * 	chunk = The ROM chunk that contains the bank.
	 * 	isCompressed = true if the bank is in the MIO0 compressed format.
	 */
	RomBank loadBank(RomChunk chunk, bool isCompressed)
	{
		// Load and add the bank to the list if it's not already there
		if (!(chunk in banks))
		{
			ubyte[] data = readChunk(chunk);
			if (isCompressed)
				data = decodeMIO0(data);

			banks[chunk] = new RomBank(this, data);
		}

		return banks[chunk];
	}
	
	/**
	 * Reads the specified chunk from the ROM and return an array containing it.
	 * Params:
	 * 	chunk = The ROM chunk to read.
	 */
	private ubyte[] readChunk(RomChunk chunk)
	{
		ubyte[] data = new ubyte[chunk.length];
		s.position = chunk.start;
		s.readExact(data.ptr, data.length);
		return data;
	}

	/**
	 * Prints a report of the contents of the ROM.
	 */
	void printResourceMap()
	{
		foreach (chunk, b; banks)
		{
			writefln("BANK FROM %.8X to %.8X", chunk.start, chunk.end);
			b.printResourceMap(chunk.start);
		}
	}

	/**
	 * Exports the contents of the ROM.
	 * Params:
	 * 	outputDirectory = The directory where the contents should be exported.
	 */
	void exportResources(string outputDirectory)
	{
		foreach (chunk, b; banks)
			b.exportResources(outputDirectory, chunk.start);
	}

	void exportLevels(string outputPath)
	{
		entryScript.exportLevels(new LevelExporterContext(this, outputPath), null);
	}
}

/// A chunk of the Mario 64 ROM.
struct RomChunk
{
	/// Start position of the chunk.
	uint start;

	/// End position of the chunk.
	uint end;

	/// Length of the chunk.
	@property uint length()
	{
		return end - start;
	}

	/**
	 * Create a RomChunk from the specified start and end positions.
	 * Params:
	 * 	start = Start position of the chunk.
	 * 	end = End position of the chunk.
	 */
	this(uint start, uint end)
	{
		enforce(end >= start, "RomChunk: end < start?");
		this.start = start;
		this.end = end;
	}
}

/// A ROM bank (a chunk of ROM which contains resource data).
class RomBank
{
	/// The ROM that contains the bank.
	private Rom rom;
	
	/// Stream containing the bank.
	private BinaryStream s;

	/// Resources in this bank, along with current offsets.
	RomBankResource[uint] resources;

	/**
	 * Create a new RomBank from the bank data.
	 * Params:
	 * 	rom = The ROM that contains the bank.
	 * 	data = The bytes of the ROM bank.
	 */
	this(Rom rom, ubyte[] data)
	{
		this.rom = rom;
		this.s = new BinaryStream(new MemoryStream(data), Endian.bigEndian);
	}

	/**
	 * Load a RomBankResource of type T from the bank.
	 * If the resource was previously loaded, its instance will be returned;
	 * If it wasn't, the resource will be really loaded from the ROM bank.
	 *
	 * Params:
	 * 	ctx = Current ROM context.
	 * 	offset = Offset in the ROM bank of the resource.
	 * 	createResource = Creates a instance of the resource.
	 *
	 * Returns: The loaded resource.
	 */
	T load(T)(RomContext ctx, uint offset, lazy T createResource) if(is(T : RomBankResource))
	{
		/* This cache accomplishes 3 tasks:
		 * - Keeps track of the resources in the bank.
		 * - Solves infinite script call cycles.
		 * - Avoids loading resources multiple times. */

		if (!(offset in resources))
		{
			ulong oldPosition = s.position;
			s.position = offset;

			/* Make sure resources[offset] is assigned before .read(),
			 * or the program will get stuck on an infinite loading loop,
			 * since it would attempt to load the same resource
			 * indefinitely if there's some dependency cycle. */				
			resources[offset] = createResource();
			resources[offset].read(ctx, s);	

			s.position = oldPosition;
		}

		return cast(T)resources[offset];
	}

	/**
	 * Prints a report of the contents of the ROM bank.
	 * Params:
	 * 	startOffset = Offset of the ROM bank in the ROM.
	 */
	void printResourceMap(uint startOffset)
	{
		void printGap(uint start, uint end)
		{			
			writefln("%.8X - %.8X: !!!%sGAP!!!", start, end, ((start + 128) < end) ? "HUGE " : "");

			s.position = start;
			ubyte[] x = s.getArray!ubyte(end - start);
			write("\t");
			foreach (b; x)
				writef("%.2X ", b);
			writeln();
		}

		uint[] sortOffs = resources.keys.sort;

		for (size_t i = 0; i < sortOffs.length; i++)
		{
			uint off = sortOffs[i];
			uint size = resources[off].size;
			uint nextOff = ((i + 1) != sortOffs.length) ? sortOffs[i + 1] : cast(uint)s.size;

			if (i == 0 && off != 0) // Gap at start of bank
				printGap(0, off);

			writefln("%.8X - %.8X: %s", off, off + resources[off].size(), resources[off].toString());

			if ((off + size) < nextOff) // Gap after current data
				printGap(off + size, nextOff);

			if ((off + size) > nextOff)
				writeln("!!!OVERLAP!!!");
		}

		writeln("***");
	}

	/**
	 * Export all resources of the ROM bank.
	 * Params:
	 * 	outputDirectory = The directory where the reosurces should be exported.
	 * 	baseOffset = Offset in the ROM of the ROM bank.
	 */
	void exportResources(string outputDirectory, uint baseOffset)
	{
		foreach (off, rsrc; resources)
		{
			IExportable exportable = cast(IExportable)rsrc;
			if (exportable is null)
				continue;

			string subDir = exportable.exportType();

			string fileName = format("%d_%.8X.%s",
				baseOffset + off,			// ROM offset
				off,						 // Bank offset
				exportable.exportExtension() // Extension
			);

			string outputDir = buildPath(outputDirectory, subDir);
			string outputPath = buildPath(outputDir, fileName);

			writefln("Exporting %s...", outputPath);
			try { mkdirRecurse(outputDir); } catch (Exception ex) { } // Hacky

			Stream output = new std.stream.BufferedFile(outputPath, FileMode.OutNew);
			scope(exit) output.close();
			exportable.exportTo(output);
		}
	}
}

/// Base class for all resources in ROM banks.
abstract class RomBankResource
{
	/// The ROM bank that contains this resource.
	private RomBank bank;

	/**
	 * Sets the bank this resource belongs to.
	 * Params:
	 * 	bank = The ROM bank to associate.
	 */
	private void assignBank(RomBank bank)
	{
		if (this.bank !is null)
		{
			writeln("INTERNAL ERROR: Trying to reassign the bank of a resource.");
			assert(false);
		}

		this.bank = bank;
	}

	/**
	 * Read the resource from the ROM.
	 * Params:
	 * 	ctx = The current ROM context.
	 * 	s = The stream that contains the resource, seeked at the resource position.
	 */
	abstract void read(RomContext ctx, BinaryStream s);

	/**
	 * Calculates the size of this resource.
	 * Returns: The size, in bytes, of this resource.
	 */
	abstract uint size();
}

/// Represents a segment identifier (just for readability).
alias ubyte Segment;

/// Represents an address in a ROM bank.
struct SegmentAddress
{
	// Stored as 0xSSOOOOOO, but bitfields starts from the LSB, so offset must go first
	mixin(bitfields!(
		uint, "offset", 24,
		ubyte, "segment", 8
	));

	/**
	 * Create a new SegmentAddress from a segment and offset.
	 * Params:
	 * 	segment = The segment specifying the ROM bank.
	 * 	offset = The offset inside the ROM bank.
	 */
	this(ubyte segment, uint offset)
	{
		this.segment = segment;
		this.offset = offset;
	}
	
	/**
	 * Checks if this SegmentAddress is the null address (0,0).
	 * Returns: true if this SegmentAddress is the "null" address.
	 */	
	bool isNull()
	{
		return segment == 0 && offset == 0;
	}

	string toString()
	{
		return format("%.2X%.6X", segment, offset);
	}
}

///  Keeps common status to all resources while loading or writing resources.
class RomContext
{
	/// The ROM that contains the resources.
	Rom rom;
	
	/// The current mapping of segments to ROM chunks.
	RomBank[Segment] segmentMap;

	/**
	 * Creates a new empty RomContext.
	 * Params:
	 * 	rom = The ROM that contains the resources.
	 */
	this(Rom rom)
	{
		this.rom = rom;
	}

	/**
	 * Creates a copy of this RomContext (used to take branches in scripts).
	 * Returns: A deep copy of this RomContext.
	 */
	RomContext dup()
	{
		auto copy = new RomContext(rom);
		foreach (k, v; segmentMap)
			copy.segmentMap[k] = v;
		return copy;
	}
	
	/**
	 * Loads a ROM bank and assigns it to a segment, so data can be read from it.
	 * Params:
	 * 	destination = The segment the map should be assigned to.
	 * 	source = The chunk of ROM that contains the bank.
	 * 	isCompressed = True if the bank is in MIO0 format.
	 */
	RomBank loadBank(Segment destination, RomChunk source, bool isCompressed)
	{
		RomBank bank = rom.loadBank(source, isCompressed);
		segmentMap[destination] = bank;
		return bank;
	}

	/**
	 * Loads a ROM bank resource. See RomBank.load for more info.
	 */
	T load(T)(lazy T createResource, SegmentAddress source)
	{
		return segmentMap[source.segment].load(this, source.offset, createResource);
	}
}

/// A 3D vector made of 16-bit signed integers, which is used in scripts.
struct Vector3D_16
{
	/// X component.
	short x;
	/// Y component.
	short y;
	/// Z component.
	short z;
}

/// A 32-bit RGBA color.
struct ColorRGBA
{
	/// Red component.
	ubyte r;
	/// Green component.
	ubyte g;
	/// Blue component.
	ubyte b;
	/// Alpha component.
	ubyte a;

	this(ubyte r, ubyte g, ubyte b, ubyte a)
	{
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}
}

/// This interface can be implemented to allow a object to be exported to a file.
interface IExportable
{
	/**
	 * Gets a very short string describing the type of the class.
	 * Returns: A very short string, describing the type of the class.
	 */
	string exportType();

	/**
	 * Gets the extension of the stream that exportTo() will generate.
	 * Returns: The extension (without dot) of the stream generated by exportTo().
	 */
	string exportExtension();

	/**
	 * Export this instance of the class to an stream.
	 */
	void exportTo(Stream s);
}
