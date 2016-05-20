module m64.animation;
import m64.binarystream;
import m64.rom;
import m64.script;

// See http://jul.rustedlogic.net/thread.php?id=1678 for more info.

class AnimationList : RomBankResource
{
	AnimationInfo[] scripts;

	override void read(RomContext ctx, BinaryStream s)
	{
		SegmentAddress animAddr;
		while (true)
		{
			animAddr = s.get!SegmentAddress;
			if (animAddr.segment == 0)
			{
				// TODO. This isn't right and overflows.
				// There must be some way to know where this ends in the behaviour script.
				break;
			}

			scripts ~= ctx.load(new AnimationInfo, animAddr);
		}
	}

	override uint size()
	{
		return SegmentAddress.sizeof * (scripts.length + 1);
	}
}

class AnimationInfo : RomBankResource
{
	mixin(implementCommand!(
		uint, "unknown1",
		uint, "unknown2",
		ushort, "frameCount",
		ushort, "numNodes", // In geo layout
		SegmentAddress, "anim1Addr",
		SegmentAddress, "anim2Addr",
		uint, "unknown6"
	));

	AnimationData1 anim1;
	AnimationData2 anim2;

	/// Called after reading a command (to load resources).
	protected void afterRead(RomContext ctx)
	{
		size_t anim2NumCmd = (numNodes + 1) * 3;
		anim2 = ctx.load(new AnimationData2(anim2NumCmd), anim2Addr);

		size_t anim1NumEntry = anim2.getMaxIndex();
		anim1 = ctx.load(new AnimationData1(anim1NumEntry), anim1Addr);
	}
}

class AnimationData1 : RomBankResource
{
	short[] values;

	this(size_t numValues)
	{
		values.length = numValues;
	}

	override void read(RomContext ctx, BinaryStream s)
	{
		values = s.getArray!short(values.length);
	}

	override uint size()
	{
		return short.sizeof * values.length;
	}
}

struct AnimationData2Command
{
	ushort count; // How many "shorts" to extract from AnimationData1
	ushort offset; // Starting offset to extract from AnimationData1
};

class AnimationData2 : RomBankResource
{
	AnimationData2Command[] commands;

	this(size_t numCmd)
	{
		commands.length = numCmd;
	}

	override void read(RomContext ctx, BinaryStream s)
	{
		commands = s.getArray!AnimationData2Command(commands.length);
	}

	override uint size()
	{
		return AnimationData2Command.sizeof * commands.length;
	}

	/// Gets the maximum index of data read from AnimationData1 (= calculate its length)
	private size_t getMaxIndex()
	{
		size_t sz = 0;
		foreach(cmd; commands)
		{
			if (cmd.offset + cmd.count > sz)
				sz = cmd.offset + cmd.count;
		}
		return sz;
	}
}
