module m64.script;

// We need to import those modules so the mixins can be used
public import m64.rom;
public import m64.binarystream;
public import std.string : format;
public import std.traits : isSomeString;
public import std.exception : enforce;

/// An script in a ROM bank.
class Script(T) : RomBankResource
{
	/// Commands of the script.
	T[] commands;

	override void read(RomContext ctx, BinaryStream s)
	{
		T cmd;
		do
		{
			cmd = T.readOpcode(ctx, s);
			cmd.read(ctx, s);
			commands ~= cmd;
		} while (!cmd.isLast);
	}

	override uint size()
	{
		uint size;
		foreach (cmd; commands)
			size += cmd.opcodeSize() + cmd.size();
		return size;
	}
}
/// Base class for all ROM bank script commands.
class ScriptCommand
{
	/**
	 * Checks if this is the last command of the script.
	 * Returns: true if this is the last command of the script.
	 */
	bool isLast()
	{
		return false;
	}

	/**
	 * Reads the data of this command.
	 * Params:
	 * 	ctx: The current ROM context.
	 * 	s: The stream that contains the command.
	 */
	abstract void read(RomContext ctx, BinaryStream s);

	/**
	 * Calculates the size used by the opcode of this command.
	 * Returns: The size of the opcode of the command.
	 */
	abstract uint opcodeSize();

	/**
	 * Calculates the size used by the data of this command.
	 * Returns: The size of the data of the command.
	 */
	abstract uint size();

	/// Called after reading a command (to load resources).
	protected void afterRead(RomContext ctx)
	{
	}

	/*
	/// Called before writting a command (to fix the resource addresses).
	protected void beforeWrite(RomContext ctx)
	{
	}
	*/
}

/**
 * Automatically implements the read(), write() and size() methods of the ScriptCommand base class.
 *
 * OpType is the type of the operation code.
 * CmdType is the base type of all commands.
 * The other arguments will be pairs of (operation code -> command type).
 */
template implementCommandDispatcher(OpType, CmdType, T...)
{
	enum implementCommandDispatcher =
		"static " ~ CmdType.stringof ~ " readOpcode(RomContext ctx, BinaryStream s) {\n" ~
			"\t" ~ OpType.stringof ~ " op = s.get!" ~ OpType.stringof ~ ";\n" ~
			"\t" ~ "switch (op) {\n" ~
				makeReadCases!(T) ~
				"\t\tdefault: throw new Exception(format(\"Unknown " ~ CmdType.stringof ~ " opcode %X\", op));\n" ~
			"\t" ~ "}\n" ~
		"}\n" ~

		"override uint opcodeSize() {\n" ~
			"return " ~ OpType.sizeof.stringof ~ ";" ~
		"}\n";
}

private template makeReadCases(T...)
{
	static if (T.length > 0)
	{
		enum makeReadCases =
			"\t\tcase " ~ T[0].stringof ~ ": return new " ~ T[1].stringof ~ ";\n" ~
			makeReadCases!(T[2..$]);
	}
	else
		enum makeReadCases = "";
}

/**
 * Automatically implements the read(), size() and write() method of a command.
 * The arguments will be pairs of (field type -> field name).
 * If field name is NOT a string, then the field is assumed to be a constant, equal to the field name.
 */
template implementCommand(T...)
{
	enum implementCommand =
		makeFields!(T) ~
		"override void read(RomContext ctx, BinaryStream s) {\n" ~
			makeReader!(T) ~
			"\tafterRead(ctx);\n" ~
		"}\n" ~
		"override size_t size() {\n" ~
			"\treturn 0" ~ makeSizer!(T) ~ ";\n"
		"}\n"/* ~
		"void write(RomContext ctx, BinaryStream s) {\n" ~
			"\tbeforeWrite(ctx);\n" ~
			makeWriter!(T) ~
		"}\n"*/;
}

private template makeFields(T...)
{
	static if (T.length > 0)
	{
		static if (isSomeString!(typeof(T[1])))
		{
			enum makeFields =
				T[0].stringof ~ " " ~ T[1] ~ ";\n" ~
				makeFields!(T[2..$]);
		}
		else
			enum makeFields = makeFields!(T[2..$]);
	}
	else
		enum makeFields = "";
}

private template makeReader(T...)
{
	static if (T.length > 0)
	{
		static if (isSomeString!(typeof(T[1])))
		{
			enum makeReader =
				"\t" ~ T[1] ~ " = s.get!" ~ T[0].stringof ~ ";\n" ~
				makeReader!(T[2..$]);
		}
		else
		{
			enum makeReader =
				"\t" ~ "enforce(s.get!" ~ T[0].stringof ~ " == " ~ T[1].stringof ~ ", \"Unknown data on \" ~ typeid(this).toString);\n" ~
				makeReader!(T[2..$]);
		}
	}
	else
		enum makeReader = "";
}

private template makeSizer(T...)
{
	static if (T.length > 0)
	{
		enum makeSizer =
			" + " ~ T[0].sizeof.stringof ~ makeSizer!(T[2..$]);
	}
	else
		enum makeSizer = "";
}

/*
private template makeWriter(T...)
{
	static if (T.length > 0)
	{
		static if (isSomeString!(typeof(T[1])))
		{
			enum makeWriter = 
				"\ts.put!" ~ T[0].stringof ~ "(" ~ T[1] ~ ");\n" ~
				makeWriter!(T[2..$]);
		}
		else
		{
			enum makeWriter =
				"\ts.put!" ~ T[0].stringof ~ "(" ~ T[1].stringof ~ ");\n" ~
				makeWriter!(T[2..$]);
		}
	}
	else
		enum makeWriter = "";
}
*/
