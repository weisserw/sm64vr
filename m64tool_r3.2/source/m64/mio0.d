module m64.mio0;
import std.stream;
import std.system;
import std.exception;
import m64.binarystream;

/* MIO0 format
 * -----------
 * -----------
 *
 * Basic description
 * -----------------
 * MIO0 is a variant of LZSS/LZ77,
 * particularly one that uses backtracking instead of a ring buffer.
 *
 * Instead of storing everything (flags, bytes, backtrack positions) in the
 * same stream, each of those things are stored in their own zone.
 *
 * Header
 * ------
 * 0x00: ASCII 'MIO0'
 * 0x04: Size, in bytes, of the output.
 * 0x08: Offset, in bytes, relative to 0x00, of the backtrack zone.
 * 0x12: Offset, in bytes, relative to 0x00, of the bytes zone.
 *
 * The flags zone always starts at offset 0x10, in bytes, relative to 0x00.
 *
 * Flags zone
 * ----------
 * Each bit of each byte specifies the next action to do.
 *
 * BYTE: ABCDEFGH
 * 
 * Bits are read from the MSB to the LSB.
 *
 * - If the bit is 1, a byte is copied from the bytes zone to the output.
 * - If the bit is 0, a backtrack offset and count is read from the backtrack
 *	 zone, and previous output data is copied to the output.
 *
 * Backtrack zone
 * --------------
 * The backtrack offset and count are packed in 2 bytes, and are decoded as follows:
 *
 * 2 BYTES: ABCDEFGH IJKLMNOP
 *
 * Count = ABCD + 3
 * BacktrackOffset = EFGHIJKLMNOP + 1
 *
 * On a 0 bit, copy Count bytes from Output[OutputPos - BacktrackOffset + n] to
 * Output[OutputPos + n], where n goes from 0 to Count.
 *
 * IMPORTANT: The source and destination zones may overlap, so it's important
 *			  to take this into acount (don't use a memcpy-like function!).
 *
 * Bytes zone
 * ----------
 * Nothing special. Just bytes copied directly from the input to the output. 
 */

public ubyte[] decodeMIO0(ubyte[] source)
{
	BinaryStream s = new BinaryStream(new MemoryStream(source), Endian.bigEndian);
	
	enforce(s.getArray!char(4) == "MIO0", "Invalid MIO0 magic.");

	uint outputSize = s.get!uint;
	uint backtrackPos = s.get!uint;
	uint bytesPos = s.get!uint;
	uint flagsPos = 0x10;

	ubyte[] output = new ubyte[outputSize];
	uint outputPos = 0;

	ubyte flags;
	int flagsAvailable = 0;
	while (outputPos < outputSize)
	{
		// Reload flags from file if required
		if (flagsAvailable == 0)
		{
			flags = source[flagsPos++];
			flagsAvailable = 8;
			}

		if ((flags & 0x80) != 0)
		{
			// Copy a byte from decData to the output
			output[outputPos++] = source[bytesPos++];
		}
		else
		{
			// Read backtrack / count and copy from old output data
			uint offset = (((source[backtrackPos+0] & 0x0F) << 8) | source[backtrackPos+1]) + 1;
			uint count = (source[backtrackPos+0] >> 4) + 3;
			backtrackPos += 2;

			size_t copyIndex = outputPos - offset;
			for (uint j = 0; j < count; j++)
				output[outputPos++] = output[copyIndex++];
		}

		// Discard current flag
		flags <<= 1; 
		flagsAvailable--;
	}

	return output;
}
