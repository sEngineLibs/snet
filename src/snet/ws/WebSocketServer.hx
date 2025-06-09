package snet.ws;

import snet.http.Requests.HttpRequest;
#if sys
import snet.internal.Server;

using StringTools;

@:access(snet.ws.WebSocketClient)
class WebSocketServer extends Server<WebSocketClient> {
	override function handleClient(client:WebSocketClient, callback:Void->Void) {
		client.onData(d -> trace(d.toString()));
		
		var data = client.socket.receive();

		if (data.length == 0) {
			log('No handshake data received from ${client.remote}');
			return;
		}

		var req:HttpRequest = data.toString();
		var key = req.headers.get("Sec-WebSocket-Key");
		if (key == null) {
			log('No handshake key received from ${client.remote}');
			return;
		}

		var acceptKey = WebSocket.computeWebSocketAcceptKey(key);
		var response = "HTTP/1.1 101 Switching Protocols\r\n" + "Upgrade: websocket\r\n" + "Connection: Upgrade\r\n" + "Sec-WebSocket-Accept: " + acceptKey
			+ "\r\n\r\n";

		client.socket.output.writeString(response);
		client.socket.output.flush();

		callback();
	}
}
#end
