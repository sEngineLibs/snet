package snet.ws;

#if (nodejs || sys)
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.crypto.Sha1;
import haxe.crypto.Base64;
import snet.internal.Socket;

using StringTools;

enum abstract OpCode(Int) from Int to Int {
	var Continuation = 0x0;
	var Text = 0x1;
	var Binary = 0x2;
	var Close = 0x8;
	var Ping = 0x9;
	var Pong = 0xA;
}

class WebSocket {
	public static function computeKey(key:String):String {
		return Base64.encode(Sha1.make(Bytes.ofString(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')));
	}

	public static function computeAcceptKey(key:String):String {
		var magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
		var sha1 = Sha1.make(Bytes.ofString(magic));
		return Base64.encode(sha1);
	}

	public static function writeFrame(data:Bytes, opcode:OpCode, isMasked:Bool, isFinal:Bool):Bytes {
		var out = new BytesBuffer();
		out.addByte((isFinal ? 0x80 : 0x00) | opcode);

		var len = data.length;
		var sizeMask = isMasked ? 0x80 : 0x00;

		if (len < 126) {
			out.addByte(len | sizeMask);
		} else if (len <= 0xFFFF) {
			out.addByte(126 | sizeMask);
			out.addByte(len >>> 8);
			out.addByte(len & 0xFF);
		} else {
			out.addByte(127 | sizeMask);
			// high 32 bits (set to zero)
			out.addByte(0);
			out.addByte(0);
			out.addByte(0);
			out.addByte(0);
			// low 32 bits
			out.addByte((len >>> 24) & 0xFF);
			out.addByte((len >>> 16) & 0xFF);
			out.addByte((len >>> 8) & 0xFF);
			out.addByte(len & 0xFF);
		}

		if (isMasked) {
			var mask = Bytes.alloc(4);
			for (i in 0...4)
				mask.set(i, Std.random(256));
			out.addBytes(mask, 0, 4); // fixed length
			for (i in 0...len) {
				out.addByte(data.get(i) ^ mask.get(i % 4));
			}
		} else {
			out.addBytes(data, 0, len);
		}

		return out.getBytes();
	}

	public static function readFrame(bytes:Bytes):{opcode:OpCode, isFinal:Bool, data:Bytes} {
		var pos = 0;

		inline function readByte():Int
			return bytes.get(pos++);

		var b1 = readByte();
		var b2 = readByte();

		var isFinal = (b1 & 0x80) != 0;
		var opcode = b1 & 0x0F;

		var isMasked = (b2 & 0x80) != 0;
		var payloadLen = b2 & 0x7F;

		if (payloadLen == 126) {
			payloadLen = (readByte() << 8) | readByte();
		} else if (payloadLen == 127) {
			// skip high 4 bytes
			for (i in 0...4)
				readByte();
			payloadLen = (readByte() << 24) | (readByte() << 16) | (readByte() << 8) | readByte();
		}

		var mask:Bytes = null;
		if (isMasked) {
			mask = Bytes.alloc(4);
			for (i in 0...4)
				mask.set(i, readByte());
		}

		var payload = Bytes.alloc(payloadLen);
		for (i in 0...payloadLen)
			payload.set(i, readByte());

		if (isMasked)
			for (i in 0...payloadLen)
				payload.set(i, payload.get(i) ^ mask.get(i % 4));

		return {
			opcode: opcode,
			isFinal: isFinal,
			data: payload
		};
	}
}
#end

enum abstract State(Int) from Int to Int {
	var CLOSED:Int = 3;
	var CLOSING:Int = 2;
	var CONNECTING:Int = 0;
	var OPEN:Int = 1;
}
