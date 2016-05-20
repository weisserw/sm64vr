module m64.binarystream;

import std.stream;
import std.string;
import std.algorithm;
import std.exception;
import std.array;
import std.traits;
import core.bitop;

public import std.stream;
public import std.system;

/* Yes, I'm aware that I've reimplemented EndianStream here.
 * BUT, it's because it's 100x faster on one of my programs (no joke),
 * because I can read arrays in one read and swap later,
 * instead of reading each item one by one and letting EndianStream swap slowly. */

/// A Stream with more useful binary IO methods
class BinaryStream : FilterStream
{
	/// Endianness of the stream.
	Endian m_endian;

	/// Create a BinaryStream from the specified stream.
	this(Stream source, Endian endian = std.system.endian)
	{
		super(source);
		this.m_endian = endian;
	}

	/// Get the endianness of the stream.
	@property Endian endianness()
	{
		return m_endian;
	}

	/// Set the endianness of the stream.
	@property void endianness(Endian newEndian)
	{
		m_endian = newEndian;
	}
	
	/// Read data of type T from the BinaryStream.
	T get(T)()
	{
		T x;

		static if (is(T == struct))
		{
			// Read each member of the struct
			foreach (i, v; x.tupleof)
				x.tupleof[i] = get!(typeof(v));
		}
		else static if (canSwap!(OriginalType!T))
		{
			source.readExact(&x, T.sizeof);
			if (m_endian != std.system.endian)
				endianSwap(&x);
		}
		else
			static assert(false);

		return x;
	}

	/// Read count elements of type T from the BinaryStream.
	T[] getArray(T)(size_t count)
	{
		T[] arr = new T[count];

		static if (is(T == struct))
		{
			// Use generic (but really slow) method	
			foreach (ref x; arr)
				x = get!T;
		}
		else static if (canSwap!(OriginalType!T))
		{
			source.readExact(arr.ptr, arr.length * T.sizeof);
			if (m_endian != std.system.endian && T.sizeof > 1)
				foreach (ref x; arr)
					endianSwap(&x);
		}
		else
			static assert(false);

		return arr;
	}

	void put(DST, SRC)(SRC x)
	{
		DST data = safeCast!DST(x);

		static if (is(DST == struct))
		{
			foreach (i, v; data.tupleof)
				put!(typeof(v))(data.tupleof[i]);
		}
		else static if (canSwap!(OriginalType!DST))
		{
			if (m_endian != std.system.endian)
				endianSwap(&data);
			source.writeExact(&data, DST.sizeof);
		}
		else
			static assert(false);
	}

	void putArray(T)(const(T)[] arr)
	{
		static if (is(T == struct))
		{
			// Use generic (but really slow) method
			foreach (x; arr)
				put(x);
		}
		else static if (canSwap!(OriginalType!T))
		{
			if (m_endian != std.system.endian && T.sizeof > 1)
			{
				T[] arrCopy = new T[arr.length];
				for (size_t i = 0; i < arr.length; i++)
				{
					arrCopy[i] = arr[i];
					endianSwap(&arrCopy[i]);
				}

				source.writeExact(arrCopy.ptr, arrCopy.length * T.sizeof);
			}
			else
			{
				source.writeExact(arr.ptr, arr.length * T.sizeof);
			}
		}
	}
	/// Makes a hex string with some of the next bytes. FOR DEBUGGING ONLY.
	string getSomeData()
	{
		ubyte[] data = getArray!ubyte(min(source.available, 128));
		return reduce!("a ~ b")(map!("format(\"%.2X \", a)")(data)); 
	}
}

/**
 * Casts from type SRC to type DST, making sure that no data is lost.
 * Params:
 * 	x = The variable to cast.
 * Returns: The variable after casting, which has the same value as the original.
 */
DST safeCast(DST, SRC)(SRC x)
{
	DST r = cast(DST)x;
	enforce(r == x, "Casting failed; probably some limit has been broken.");
	return r;
}

/**
 * Returns a number that is the first multiple of "alignment" greater or equal than "x".
 * Params:
 * 	x = The number to align.
 * 	alignment = The alignment to apply.
 * Returns: The aligned number.
 */
T paddingAlign(T)(T x, size_t alignment)
{
	return (x + alignment - 1) & ~(alignment - 1);
}

private template canSwap(T)
{
	// Missing (rarely used) types: real, ifloat, idouble, ireal, cfloat, cdouble, creal
	enum canSwap =
		is(T == byte) || is(T == ubyte) || is(T == char) ||
		is(T == short) || is(T == ushort) || is(T == wchar) ||
		is(T == int) || is(T == uint) || is(T == dchar) || is(T == float) ||
		is(T == long) || is(T == ulong) || is(T == double);
}

void endianSwap(T)(T *ptr)
{
	static if (T.sizeof == 1)
	{
		// Nothing to do
		return;
	}
	else static if (T.sizeof == 2)
	{
		// Swap manually (AA BB -> BB AA)
		ushort x = *cast(ushort *)ptr;
		x = cast(ushort)((x << 8) | (x >> 8));
		*cast(ushort *)ptr = x;
	}
	else static if (T.sizeof == 4)
	{
		// Use CPU swap operation from std.intrinsic
		*cast(uint *)ptr = bswap(*cast(uint *)ptr);
	}
	else static if (T.sizeof == 8)
	{
		// Split in two 32-bit integers, swap each, and put in reverse order
		// [AA BB CC DD] [EE FF GG HH] -> [DD CC BB AA] [HH GG FF EE] -> [HH GG FF EE] [DD CC BB AA]
		ulong x = *cast(ulong *)ptr;
		x = (cast(ulong)bswap(cast(uint)x) << 32) | bswap(cast(uint)(x >> 32));
		*cast(ulong *)ptr = x;
	}		
}
