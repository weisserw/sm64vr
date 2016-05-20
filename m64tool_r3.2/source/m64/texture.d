module m64.texture;
import m64.binarystream;
import m64.rom;
import m64.script;
import std.bitmanip;
import std.stream;
import std.system;

enum TextureFormat : ubyte
{
	RGBA5551 = 0x10,
	IA88 = 0x70
};
import std.stdio;

class Texture : RomBankResource, IExportable
{
	PixelFormat pixFmt;
	int width;
	int height;

	ColorRGBA[] pixelData;

	this(TextureFormat format, int width, int height)
	{
		// TODO
		if (format == TextureFormat.RGBA5551)
			this.pixFmt = new RGBA5551PixelFormat();
		else if (format == TextureFormat.IA88)
			this.pixFmt = new IA88PixelFormat();
		else
			throw new Exception("Pixelformat not implemented TODO");

		this.width = width;
		this.height = height;
	}

	override void read(RomContext ctx, BinaryStream s)
	{
		pixelData = new ColorRGBA[width * height];

		foreach (ref pix; pixelData)
			pix = pixFmt.readPixel(s);
	}

	override uint size()
	{
		return width * height * pixFmt.pixelSize();
	}

	// *** IExportable implementation ***
	string exportType()
	{
		return "Texture";
	}

	string exportExtension()
	{
		return "bmp";
	}

	void exportTo(Stream output)
	{	
		// TODO check the rest of the program to see if all structs are OK
		// DMD 2.60 changed the align behaviour and this broke
		
		align(1) struct BITMAPFILEHEADER { align(1) {	
			ushort bfType;
			uint   bfSize;
			ushort bfReserved1;
			ushort bfReserved2;
			uint   bfOffBits;
		}};
		
		align(1) struct BITMAPINFOHEADER { align(1) {
			uint   biSize;
			int	biWidth;
			int	biHeight;
			ushort biPlanes;
			ushort biBitCount;
			uint   biCompression;
			uint   biSizeImage;
			int	biXPelsPerMeter;
			int	biYPelsPerMeter;
			uint   biClrUsed;
			uint   biClrImportant;
		}};
		
		BITMAPFILEHEADER fileHdr;
		BITMAPINFOHEADER infoHdr;
		uint imageDataSize = width * height * 4;
		
		fileHdr.bfType = 0x4D42; // ASCII "BM"
		fileHdr.bfSize = BITMAPFILEHEADER.sizeof + BITMAPINFOHEADER.sizeof + imageDataSize;
		fileHdr.bfReserved1 = 0;
		fileHdr.bfReserved2 = 0;
		fileHdr.bfOffBits = BITMAPFILEHEADER.sizeof + BITMAPINFOHEADER.sizeof;
		
		infoHdr.biSize = BITMAPINFOHEADER.sizeof;
		infoHdr.biWidth = width;
		infoHdr.biHeight = height;
		infoHdr.biPlanes = 1;
		infoHdr.biBitCount = 32;
		infoHdr.biCompression = 0; // BI_RGB = Uncompressed
		infoHdr.biSizeImage = imageDataSize;
		infoHdr.biXPelsPerMeter = 0; // Don't care
		infoHdr.biYPelsPerMeter = 0; // Don't care
		infoHdr.biClrUsed = 0; // No palette
		infoHdr.biClrImportant = 0; // No palette
		
		BinaryStream s = new BinaryStream(new EndianStream(output, Endian.littleEndian));
		s.put!BITMAPFILEHEADER(fileHdr);
		s.put!BITMAPINFOHEADER(infoHdr);
		foreach (px; pixelData)
		{
			s.put!ubyte(px.b);
			s.put!ubyte(px.g);
			s.put!ubyte(px.r);
			s.put!ubyte(px.a);
		}

		/+ This exports to TGA (simpler, but sadly less supported).
		BinaryStream s = new BinaryStream(new EndianStream(output, Endian.littleEndian));

		s.put!ubyte(0); // Don't use comment field
		s.put!ubyte(0); // No palette
		s.put!ubyte(2); // Uncompressed color data
	
		s.put!ushort(0); // No palette info
		s.put!ushort(0); // No palette info
		s.put!ubyte(0); // No palette info
	
		s.put!ushort(0); // X origin 0
		s.put!ushort(0); // Y origin 0

		s.put!ushort(width);
		s.put!ushort(height);
		s.put!ubyte(32); // 32 bpp (BGRA8888 format)
		s.put!ubyte(0b00100000); // Flag to start image at upper-left corner

		foreach (px; pixelData)
		{
			s.put!ubyte(px.b);
			s.put!ubyte(px.g);
			s.put!ubyte(px.r);
			s.put!ubyte(px.a);
		}
		+/
	}
}

abstract class PixelFormat
{
	abstract uint pixelSize();
	abstract ColorRGBA readPixel(BinaryStream s);	
}

class RGBA5551PixelFormat : PixelFormat
{
	private struct RGBA5551Pixel
	{
		mixin(bitfields!(
			ubyte, "a", 1,
			ubyte, "b", 5,
			ubyte, "g", 5,
			ubyte, "r", 5
		));
	}

	override uint pixelSize()
	{
		return RGBA5551Pixel.sizeof;
	}

	override ColorRGBA readPixel(BinaryStream s)
	{
		RGBA5551Pixel px = s.get!RGBA5551Pixel;
		ubyte r = ScaleBits!(5, 8)(px.r);
		ubyte g = ScaleBits!(5, 8)(px.g);
		ubyte b = ScaleBits!(5, 8)(px.b);
		ubyte a = ScaleBits!(1, 8)(px.a);
		return ColorRGBA(r, g, b, a);
	}
}

class IA88PixelFormat : PixelFormat
{
	private struct IA88Pixel
	{
		mixin(bitfields!(
			ubyte, "a", 8,
			ubyte, "i", 8
		));
	}

	override uint pixelSize()
	{
		return IA88Pixel.sizeof;
	}

	override ColorRGBA readPixel(BinaryStream s)
	{
		IA88Pixel px = s.get!IA88Pixel;
		return ColorRGBA(px.i, px.i, px.i, px.a);
	}
}
		
/// Transforms a SRC-bit value to a DST-bit value.
private T ScaleBits(uint S, uint D, T)(T src)
{
	return cast(T)(src * ((1 << D) - 1) / ((1 << S) - 1));
}
