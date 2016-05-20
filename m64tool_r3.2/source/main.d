import std.stdio;
import std.stream;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import m64.rom;

void tryMkdir(string dirName)
{
	try { mkdir(dirName); } catch (Exception ex) { }
}

void swapRom(ubyte[] rom)
{
	if (rom[0] == 0x80 && rom[1] == 0x37 && rom[2] == 0x12 && rom[3] == 0x40)
	{
		// No need to swap
	}
	else if (rom[0] == 0x37 && rom[1] == 0x80 && rom[2] == 0x40 && rom[3] == 0x12)
	{
		// Swap 16 bit
		for (size_t i = 0; i < rom.length; i += 2)
		{
			swap(rom[i+0], rom[i+1]);
		}
	}
	else if (rom[0] == 0x40 && rom[1] == 0x12 && rom[2] == 0x37 && rom[3] == 0x80)
	{
		// Swap 32 bit
		for (size_t i = 0; i < rom.length; i++)
		{
			swap(rom[i+0], rom[i+3]);
			swap(rom[i+1], rom[i+2]);
		}		
	}
}

int main(string[] args)
{
	if (args.length < 2)
	{
		writeln("USAGE: m64tool rom.z64");
		return -1;
	}
	
	string romPath = args[1];
	
	ubyte[] romBytes = cast(ubyte[])std.file.read(romPath);
	swapRom(romBytes);

	Stream romFile = new std.stream.MemoryStream(romBytes);	
	scope(exit) romFile.close();

	writeln("Parsing ROM...");
	Rom rom = new Rom(romFile);
	
	writeln("Extracting files... BE PATIENT!");
	string romDir = dirName(romPath);
	rom.exportLevels(buildPath(romDir, "M64_Levels"));
	rom.exportResources(buildPath(romDir, "M64_Exports"));
	// rom.printResourceMap();

	writeln("END!");
	return 0;
}
