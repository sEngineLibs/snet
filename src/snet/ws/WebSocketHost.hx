package snet.websocket;

import snet.Net.NetHost;
#if sys
import haxe.io.Bytes;
import sys.net.Socket;

using StringTools;

class WebSocketHost extends NetHost<Message, WebSocketClient> {
	@async extern overload inline function send(text:String):Void {
		for (client in clients)
			client.send(text);
	}

	@async extern overload override inline function send(data:Bytes):Void {
		for (client in clients)
			client.send(data);
	}

	@async extern overload inline function broadcast(text:String, ?exclude:Array<WebSocketClient>):Void {
		if (isClosed) {
			onerror("Host is closed");
			return;
		}
		for (client in clients)
			if (!exclude.contains(client))
				client.send(text);
	}

	@async extern overload override inline function broadcast(data:Bytes, ?exclude:Array<WebSocketClient>):Void {
		if (isClosed) {
			onerror("Host is closed");
			return;
		}
		for (client in clients)
			if (!exclude.contains(client))
				client.send(data);
	}

	@async function handleClient(socket:Socket):Void {
		try {
			var peer = socket.peer();

			// Read HTTP WebSocket upgrade request
			var req = "";
			while (!req.endsWith("\r\n\r\n")) {
				var b = Bytes.alloc(1);
				var len = socket.input.readBytes(b, 0, 1);
				if (len <= 0)
					break;
				req += b.toString();
			}

			var key = extractWebSocketKey(req);
			if (key == null) {
				socket.close();
				return;
			}

			var acceptKey = computeWebSocketAcceptKey(key);
			var response = "HTTP/1.1 101 Switching Protocols\r\n" + "Upgrade: websocket\r\n" + "Connection: Upgrade\r\n" + "Sec-WebSocket-Accept: "
				+ acceptKey + "\r\n\r\n";

			socket.output.writeString(response);
			socket.output.flush();

			var client = new WebSocketClient(peer.host.host, peer.port);
			client.socket = socket;
			client.local = local;
			client.isClosed = false;

			client.onmessage = msg -> {
				if (onClientMessage != null)
					onClientMessage(client, msg);
			};
			client.onclose = () -> {
				clients.remove(client);
				if (onClientClose != null)
					onClientClose(client);
			};

			clients.push(client);
			if (onClientOpen != null)
				onClientOpen(client);

			@await client.process();
		} catch (e) {
			onerror("WebSocket handleClient onerror: " + e.message);
		}
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
