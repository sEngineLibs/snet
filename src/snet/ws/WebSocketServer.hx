package snet.ws;

#if (nodejs || sys)
import haxe.io.Bytes;
import snet.Net;
import snet.http.Http;
import snet.ws.WebSocket;
import snet.internal.Server;

using StringTools;

@:access(snet.ws.WebSocketClient)
class WebSocketServer extends Server<WebSocketClient> {
	overload extern public inline function send(text:String):Void {
		broadcast(text);
	}

	overload extern public inline function broadcast(text:String, ?exclude:Array<WebSocketClient>):Void {
		if (isClosed)
			throw new NetError("Not open");
		exclude = exclude ?? [];
		for (client in clients)
			if (!exclude.contains(client))
				client.send(text);
	}

	override function handleClient(client:WebSocketClient) {
		var data = client.socket.read(1.0);

		if (data.length == 0) {
			logger.error('No handshake data received from ${client.remote}');
			return;
		}

		var req:HttpRequest = data.toString();
		var resp:HttpResponse = {};

		resp.headers.set(SEC_WEBSOCKET_VERSION, "13");
		if (req.method != "GET" || req.version != "HTTP/1.1") {
			resp.status = 400;
			resp.statusText = "Bad";
			resp.headers.set(CONNECTION, "close");
			resp.headers.set(X_WEBSOCKET_REJECT_REASON, 'Bad request');
		} else if (req.headers.get(SEC_WEBSOCKET_VERSION) != "13") {
			resp.status = 426;
			resp.statusText = "Upgrade";
			resp.headers.set(CONNECTION, "close");
			resp.headers.set(X_WEBSOCKET_REJECT_REASON,
				'Unsupported websocket client version: ${req.headers.get(SEC_WEBSOCKET_VERSION)}, Only version 13 is supported.');
		} else if (req.headers.get(UPGRADE) != "websocket") {
			resp.status = 426;
			resp.statusText = "Upgrade";
			resp.headers.set(CONNECTION, "close");
			resp.headers.set(X_WEBSOCKET_REJECT_REASON, 'Unsupported upgrade header: ${req.headers.get(UPGRADE)}.');
		} else if (req.headers.get(CONNECTION).indexOf("Upgrade") == -1) {
			resp.status = 426;
			resp.statusText = "Upgrade";
			resp.headers.set(CONNECTION, "close");
			resp.headers.set(X_WEBSOCKET_REJECT_REASON, 'Unsupported connection header: ${req.headers.get(CONNECTION)}.');
		} else {
			var key = req.headers.get(SEC_WEBSOCKET_KEY);
			resp.status = 101;
			resp.statusText = "Switching Protocols";
			resp.headers.set(UPGRADE, "websocket");
			resp.headers.set(CONNECTION, "Upgrade");
			resp.headers.set(SEC_WEBSOCKET_ACCEPT, WebSocket.computeAcceptKey(key));
		}

		client.socket.output.write(Bytes.ofString(resp));
		client.socket.output.flush();
	}
}
#end
