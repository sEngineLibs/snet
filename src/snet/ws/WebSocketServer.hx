package snet.ws;

#if sys
import haxe.io.Bytes;
import snet.internal.Socket;
import snet.internal.Server;

using StringTools;

@:access(snet.ws.WebSocketClient)
class WebSocketServer extends Server<WebSocketClient> {
	@async override function handleClient(socket:Socket):Bool {
		var data = @await socket.receive();
		if (data.length == 0)
			return false;

		var req = data.toString();
		var key = extractWebSocketKey(req);
		if (key == null)
			return false;

		var acceptKey = computeWebSocketAcceptKey(key);
		var response = "HTTP/1.1 101 Switching Protocols\r\n" + "Upgrade: websocket\r\n" + "Connection: Upgrade\r\n" + "Sec-WebSocket-Accept: " + acceptKey
			+ "\r\n\r\n";

		socket.output.writeString(response);
		socket.output.flush();
	}

	static function extractWebSocketKey(request:String):String {
		for (line in request.split("\r\n"))
			if (line.startsWith("Sec-WebSocket-Key:"))
				return StringTools.trim(line.substr("Sec-WebSocket-Key:".length));
		return null;
	}

	static function computeWebSocketAcceptKey(key:String):String {
		var magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
		var sha1 = haxe.crypto.Sha1.make(Bytes.ofString(magic));
		return haxe.crypto.Base64.encode(sha1);
	}
}
#end
