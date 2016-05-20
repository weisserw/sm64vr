module m64.behaviour;
import std.stream;
import m64.binarystream;
import m64.rom;
import m64.script;
import m64.animation;
import m64.collision;

import std.stream;

/* Information sources:
 * M64 Hacking Doc 1.5 by VL-Tone.
 * http://jul.rustedlogic.net/thread.php?id=2190.
 * Cellar Dweller's docs (BEST SOURCE!).
 * Dudaw's Homepage - List of Behavioral Commands.
 */

/* The "index" variable of the commands that modify data map to:
 * - ObjectStruct + 0x88 + Index * 4.
 *
 * Some indices:
 * - 0x06, 0x07, 0x08: Position (float)
 * - 0x12, 0x13, 0x14: Rotation (int).
 * - 0x26: Animation pointer (SegmentAddress).
 * - 0x3D: Transparency (int).
 * - 0x45: Draw distance (float).
 *
 * More information can be found at the "Mario C header files" by messiaen.
 * (ObjectStruct is in mario64.h, "struct object").
 */

class BehaviourScript : Script!BehaviourCommand
{
}

abstract class BehaviourCommand : ScriptCommand
{
	mixin(implementCommandDispatcher!(
		ubyte, BehaviourCommand,

		0x00, Behaviour00,
		0x01, Behaviour01,
		0x02, Behaviour02,
		0x03, Behaviour03,
		0x04, BehaviourJump,
		0x08, BehaviourSetJump,
		0x09, BehaviourGoToJump,
		0x0A, Behaviour0A,
		0x0C, BehaviourCallRam,
		0x0D, Behaviour0D,
		0x0E, BehaviourSetFloatFromShort,
		0x0F, BehaviourAddShortToInteger,
		0x10, BehaviourSetIntegerFromShort,
		0x11, BehaviourOrIntegerFromShort,
		0x13, Behaviour13,
		0x1B, Behaviour1B,
		0x1C, BehaviourCreateObject1C, // Set child behaviour
		0x1D, Behaviour1D,
		0x1E, BehaviourKeepOnGround,
		0x21, BehaviourSetFlag,
		0x22, Behaviour22,
		0x23, BehaviourSetCollisionSphere,
		0x27, BehaviourAnimation,
		0x28, BehaviourCallSomethingAnimation,
		0x29, BehaviourCreateObject29, 
		0x2A, BehaviourSetSolidCollision,
		0x2B, Behaviour2B,
		0x2C, Behaviour2C, // Set child behaviour
		0x2D, BehaviourCopyPosition,
		0x2E, Behaviour2E,
		0x2F, BehaviourSetNonSolidCollision,
		0x30, BehaviourSetSomeValues, // Set gravity
		0x32, BehaviourScale,
		0x34, Behaviour34,
		0x35, Behaviour35,
	));
}

/**
 * if (0x802a14fc(0x13004fd4)) {  // Haunted Chair
 *	   0x802a4120();
 * }
 * 
 * if (0x802a14fc(0x13005024)) { // Mad piano
 *	   0x802a4120();
 * }
 *
 * if (0x802a14fc(0x130032e0)) { // Message panel
 *	   (*(0x80361160))->off0x194 = 150.0;
 * }
 */
class Behaviour00 : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1",
		ubyte, "unknown2",
		ubyte, "unknown3"
	));
}

class Behaviour01 : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, 0,
		ubyte, "unknown"
	));
}

/**
 * This command is only used once, and loads the behaviour script at 0x00219E00+0x0000243C.
 * That script is 0x10 bytes in size and contains a new behaviour command, 0x03, which terminates the script.
 */
class Behaviour02 : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		SegmentAddress, "behaviourAddr"
	));

	BehaviourScript behaviour;

	protected override void afterRead(RomContext ctx)
	{
		ctx.load(new BehaviourScript, behaviourAddr);
	}
}

/// Only used to return from the only behaviour script launched by 0x02.
class Behaviour03 : BehaviourCommand
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

/// Jump to other behaviour data
class BehaviourJump : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		SegmentAddress, "jumpAddr"
	));

	BehaviourScript jump;

	protected override void afterRead(RomContext ctx)
	{
		jump = ctx.load(new BehaviourScript, jumpAddr);
	}

	override bool isLast()
	{
		return true;
	}
}

/// Save current location on the top of the stack.
class BehaviourSetJump : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

/// Jump to the top of the stack without poping the value.
class BehaviourGoToJump : BehaviourCommand
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

class Behaviour0A : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));

	override bool isLast()
	{
		// TODO Not sure
		return true;
	}
}

import std.stdio;

class BehaviourCallRam : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, "funcAddr"
	));
}

class Behaviour0D : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1",
		short, "unknown2"
	));
}

/// Sets the float value at the specified index from a 16-bit integer value.
/// object[index] = (float)value;
class BehaviourSetFloatFromShort : BehaviourCommand
{	 
	mixin(implementCommand!(
		ubyte, "index",
		short, "value"
	));
}

/// Adds a 16-bit integer value to the 32-bit integer value at the specified index.
/// object[index] += (int)value;
class BehaviourAddShortToInteger : BehaviourCommand
{	 
	mixin(implementCommand!(
		ubyte, "index",
		short, "value"
	));
}

/// Sets the 32-bit integer value at the specified index from a 16-bit integer value.
/// object[index] = (int)value;
class BehaviourSetIntegerFromShort : BehaviourCommand
{	 
	mixin(implementCommand!(
		ubyte, "index",
		short, "value"
	));
}

/// ORs the 32-bit integer at the specified index by a 16-bit integer value (low bits).
// object[index] |= value;
class BehaviourOrIntegerFromShort : BehaviourCommand
{	 
	mixin(implementCommand!(
		ubyte, "index",
		ushort, "value"
	));
}

class Behaviour13 : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, "unknown1",
		ubyte, 0,
		ubyte, "unknown2"
	));
}

class Behaviour1B : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ubyte, 0,
		ubyte, "unknown"
	));
}

class BehaviourCreateObject1C : BehaviourCommand
{
	// TODO join with other CreateObject?

	mixin(implementCommand!(
		ushort, 0,
		uint, 0,
		ubyte, "id", // Defined in 0x21/0x22 of level scripts.
		SegmentAddress, "behaviourAddr",
	));

	BehaviourScript behaviour;

	protected override void afterRead(RomContext ctx)
	{
		behaviour = ctx.load(new BehaviourScript, behaviourAddr);
	}
}

class Behaviour1D : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));

	override bool isLast()
	{
		// TODO not sure... needs more testing		
		return true;
	}
}

/// (Suposedly) Sticks the object to the ground
class BehaviourKeepOnGround : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

/**
 * (*(0x80361160))->off0x02 |= 4; (graph_flags)
 * According to Dudaw docs, this sets billboarding (object always faces camera).
 */
class BehaviourSetFlag : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

class Behaviour22 : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

/// Sets the float values at object->1F8/1FC (collision sphere) from the specified 16-bit values.
class BehaviourSetCollisionSphere : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		ushort, "value1",
		ushort, "value2"
	));
}

import std.stdio;

/// Sets the object animation.
/// (Should be "Sets the value of the specified index to the specified 32-bit index",
///  but the index is always 0x26, the animation pointer).
class BehaviourAnimation : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0x26,
		ushort, 0,
		SegmentAddress, "animationAddr"
	));

	AnimationList anims;

	protected override void afterRead(RomContext ctx)
	{
		//writeln(animationAddr);
		// TODO need to find animation size from somewhere...
		anims = ctx.load(new AnimationList, animationAddr);
	}
}

/**
 * Probably related to animation.
 * Does 0x8037c658(object, object->120 (animation ptr) + unknown*4);
 */
class BehaviourCallSomethingAnimation : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, "unknown",
		ushort, 0
	));
}

class BehaviourCreateObject29 : BehaviourCommand
{
	// TODO join with other CreateObject?

	mixin(implementCommand!(
		ushort, 0,
		uint, 0,
		ubyte, "objectId", // Defined in 0x21/0x22 of level scripts.
		SegmentAddress, "behaviourAddr",
	));

	BehaviourScript behaviour;

	protected override void afterRead(RomContext ctx)
	{
		behaviour = ctx.load(new BehaviourScript, behaviourAddr);
	}
}

class BehaviourSetSolidCollision : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		SegmentAddress, "collisionAddr"
	));

	CollisionData collision;

	protected override void afterRead(RomContext ctx)
	{
		collision = ctx.load(new CollisionData, collisionAddr);
	}
}

class Behaviour2B : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		Vector3D_16, "unknown",
		ushort, 0
	));
}

class Behaviour2C : BehaviourCommand
{
	// TODO join with other CreateObject?

	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, 0,
		SegmentAddress, "behaviourAddr",
	));

	BehaviourScript behaviour;

	protected override void afterRead(RomContext ctx)
	{
		behaviour = ctx.load(new BehaviourScript, behaviourAddr);
	}
}

/// Copies the position from object->A0/A4/A8 to object->164/168/16C
class BehaviourCopyPosition : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

class Behaviour2E : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}

/* List of non-solid collisions by Dudaw:
00000001: Mario can hang from it
00000002: Mario can pick it up
00000004: Door
00000008: Damages Mario (normal)
00000010: Coin
00000020: Nothing?
00000040: Pole
00000080: Damages Mario (can be punched and bounced on)
00000100: Damages Mario (can be punched)
00000200: Nothing (can be punched)
00000400: Blows Mario away
00000800: Warp door
00001000: Star
00002000: Warp hole
00004000: Cannon
00008000: Damages Mario (can be punched and bounced on)
00010000: Replenishes health
00020000: Bully
00040000: Flame
00080000: Koopa shell
00100000: Damages Mario (can be punched and bounced on)
00200000: Damages Mario
00400000: Damages Mario (can be punched and bounced on)
00800000: Message
01000000: Makes Mario spin
02000000: Makes Mario fall?
04000000: Damages Mario
08000000: Warp (Mario shrinks in)
10000000: Damages Mario
20000000: Electrocutes Mario
40000000: Normal
80000000: Nothing?
*/
class BehaviourSetNonSolidCollision : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		uint, "flags"
	));
}

/**
 * object->128 = (float)value1;
 * object->E4 = (float)value2 / 100.0;
 * object->158 = (float)value3 / 100.0;
 * object->12C = (float)value4 / 100.0;
 * object->170 = (float)value5 / 100.0;
 * object->174 = (float)value6 / 100.0;
 */
class BehaviourSetSomeValues : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0,
		short, "value1",
		short, "value2",
		short, "value3",
		short, "value4",
		short, "value5",
		short, "value6",
		uint, 0
	));
}

/// Scales the object and its collision data using the specified percentage.
class BehaviourScale : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, "percent"
	));
}

class Behaviour34 : BehaviourCommand
{
	// This may be another command to modify the object structure

	mixin(implementCommand!(
		ubyte, 0x1A, // Texture animation rate?
		ubyte, 0,
		ubyte, "unknown", // 0x02 or 0x04. Flags?
	));
}

class Behaviour35 : BehaviourCommand
{
	mixin(implementCommand!(
		ubyte, 0,
		ushort, 0
	));
}
