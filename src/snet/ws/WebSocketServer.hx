// package snet.ws;

// import snet.internal.Server;
// #if sys
// import haxe.io.Bytes;
// import sys.net.Socket;
// import sasync.Async;
// import snet.ws.WebSocket;
// import snet.internal.HostInfo;

// using StringTools;

// @:access(snet.ws.WebSocketClient)
// class WebSocketServer extends Server<WebSocketClient> {
// 	@async function handleClient(socket:Socket):Void @:privateAccess {
// 		var data = @await WebSocket.receive(socket);
// 		if (data.length == 0)
// 			throw "No handshake data received";

// 		var req = data.getBytes().toString();
// 		var key = extractWebSocketKey(req);
// 		if (key == null) {
// 			socket.close();
// 			return;
// 		}

// 		var acceptKey = computeWebSocketAcceptKey(key);
// 		var response = "HTTP/1.1 101 Switching Protocols\r\n" + "Upgrade: websocket\r\n" + "Connection: Upgrade\r\n" + "Sec-WebSocket-Accept: " + acceptKey
// 			+ "\r\n\r\n";

// 		socket.output.writeString(response);
// 		socket.output.flush();
// 	}

// 	static function extractWebSocketKey(request:String):String {
// 		for (line in request.split("\r\n"))
// 			if (line.startsWith("Sec-WebSocket-Key:"))
// 				return StringTools.trim(line.substr("Sec-WebSocket-Key:".length));
// 		return null;
// 	}

// 	static function computeWebSocketAcceptKey(key:String):String {
// 		var magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
// 		var sha1 = haxe.crypto.Sha1.make(Bytes.ofString(magic));
// 		return haxe.crypto.Base64.encode(sha1);
// 	}
// }
// #end
