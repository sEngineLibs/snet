package snet.ws;

#if sys
import haxe.Exception;
import haxe.io.Bytes;
import haxe.crypto.Sha1;
import haxe.crypto.Base64;
import snet.internal.Buffer;
import snet.internal.Socket;

using StringTools;

enum Message {
	Text(text:String);
	Binary(data:Bytes);
}

enum abstract OpCode(Int) from Int to Int {
	var Continuation = 0x0;
	var Text = 0x1;
	var Binary = 0x2;
	var Close = 0x8;
	var Ping = 0x9;
	var Pong = 0xA;
}

class WebSocketError extends Exception {}

class WebSocket {
	public static function extractWebSocketKey(request:String):String {
		for (line in request.split("\r\n"))
			if (line.startsWith("Sec-WebSocket-Key:"))
				return StringTools.trim(line.substr("Sec-WebSocket-Key:".length));
		return null;
	}

	public static function computeWebSocketKey(key:String):String {
		return Base64.encode(Sha1.make(Bytes.ofString(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')));
	}

	public static function computeWebSocketAcceptKey(key:String):String {
		var magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
		var sha1 = haxe.crypto.Sha1.make(Bytes.ofString(magic));
		return haxe.crypto.Base64.encode(sha1);
	}

	public static function writeFrame(data:Bytes, opcode:OpCode, isMasked:Bool, isFinal:Bool):Bytes {
		var mask = Bytes.alloc(4);
		for (i in 0...4)
			mask.set(i, Std.random(256));
		var sizeMask = isMasked ? 0x80 : 0x00;

		var out = new Buffer();
		out.writeByte((isFinal ? 0x80 : 0x00) | opcode);

		var len = data.length;
		if (len < 126) {
			out.writeByte(len | sizeMask);
		} else if (len <= 0xFFFF) {
			out.writeByte(126 | sizeMask);
			out.writeByte(len >>> 8);
			out.writeByte(len & 0xFF);
		} else {
			out.writeByte(127 | sizeMask);
			// no UInt64 in haxe so 0 + 32 bit
			out.writeByte(0);
			out.writeByte(0);
			out.writeByte(0);
			out.writeByte(0);
			out.writeByte((len >>> 24) & 0xFF);
			out.writeByte((len >>> 16) & 0xFF);
			out.writeByte((len >>> 8) & 0xFF);
			out.writeByte(len & 0xFF);
		}

		if (isMasked) {
			out.writeBytes(mask);
			var payload = Bytes.alloc(len);
			for (i in 0...len)
				payload.set(i, data.get(i) ^ mask.get(i % 4));
			out.writeBytes(payload);
		} else {
			out.writeBytes(data);
		}

		return out.readAllAvailableBytes();
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
#end
