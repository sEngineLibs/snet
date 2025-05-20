package snet.ws;

#if sys
import sys.net.Socket;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

using snet.ws.WebSocket;

class WebSocket {
	public static function writeFrame(data:Bytes, opcode:OpCode, isMasked:Bool, isFinal:Bool):Bytes {
		var mask = Bytes.alloc(4);
		for (i in 0...4)
			mask.set(i, Std.random(256));
		var sizeMask = isMasked ? 0x80 : 0x00;

		var out = new BytesBuffer();
		out.addByte((isFinal ? 0x80 : 0x00) | opcode);

		var len = data.length;
		if (len < 126) {
			out.addByte(len | sizeMask);
		} else if (len <= 0xFFFF) {
			out.addByte(126 | sizeMask);
			out.addByte(len >>> 8);
			out.addByte(len & 0xFF);
		} else {
			out.addByte(127 | sizeMask);
			// no UInt64 in haxe so 0 + 32 bit
			out.addByte(0);
			out.addByte(0);
			out.addByte(0);
			out.addByte(0);
			out.addByte((len >>> 24) & 0xFF);
			out.addByte((len >>> 16) & 0xFF);
			out.addByte((len >>> 8) & 0xFF);
			out.addByte(len & 0xFF);
		}

		if (isMasked) {
			out.addBytes(mask, out.length, mask.length);
			var payload = Bytes.alloc(len);
			for (i in 0...len)
				payload.set(i, data.get(i) ^ mask.get(i % 4));
			out.addBytes(payload, out.length, mask.length);
		} else
			out.addBytes(data, out.length, mask.length);

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

	public static function sendFrame(socket:Socket, data:Bytes, opcode:OpCode):Void {
		socket.output.write(WebSocket.writeFrame(data, opcode, true, true));
		socket.output.flush();
	}
}

enum abstract BinaryType(String) {
	var BLOB = "blob";
	var ARRAYBUFFER = "arraybuffer";
}

enum abstract OpCode(Int) from Int to Int {
	var Continuation = 0x0;
	var Text = 0x1;
	var Binary = 0x2;
	var Close = 0x8;
	var Ping = 0x9;
	var Pong = 0xA;
}

enum Message {
	Text(text:String);
	Binary(data:Bytes);
}

@:forward.new
@:forward(host, port)
abstract HostInfo(HostInfoData) {
	@:to
	public inline function toString():String {
		return '${this.host}:${this.port}';
	}
}

class HostInfoData {
	public var host:String;
	public var port:Int;

	public inline function new(host:String, port:Int) {
		this.host = host;
		this.port = port;
	}
}
#end
