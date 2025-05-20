package snet.ws;

#if sys
import haxe.io.Bytes;
import sys.net.Socket;
import snet.Net;
import snet.ws.WebSocket;

using StringTools;

class WebSocketHost {
	var socket:Socket;

	public var isClosed(default, null):Bool = true;

	public var local(default, null):HostInfo;
	public var remote(default, null):HostInfo;

	public var clients:Array<WebSocketClient> = [];
	public var limit(default, null):Int;

	public var onstart:() -> Void = () -> {};
	public var onclose:() -> Void = () -> {};
	public var onerror:(message:String) -> Void = _ -> {};

	public var onClientOpen:(connection:WebSocketClient) -> Void = _ -> {};
	public var onClientClose:(connection:WebSocketClient) -> Void = _ -> {};
	public var onClientMessage:(connection:WebSocketClient, message:Message) -> Void = (_, _) -> {};

	public function new(host:String, port:Int, immediateStart:Bool = true, limit:Int = 10) {
		super(host, port, false);
		local = remote;
		remote = null;
		this.limit = limit;
		if (immediateStart)
			start();
	}

	public function start():Void {
		if (!isClosed)
			onerror("Socket is not closed");
		else {
			socket = new Socket();
			try {
				socket.setBlocking(true);
				socket.bind(new sys.net.Host(local.host), local.port);
				socket.listen(limit);
				isClosed = false;

				onstart();
				process();
			} catch (e) {
				if (onerror != null)
					onerror('Failed to start server on $local: ${e.message}');
				socket.close();
				return;
			}
		}
	}

	public function broadcast(message:Message, ?exclude:Array<HostInfo>):Void {
		function ex(info:HostInfo) {
			for (i in exclude)
				if (i.host == info.host && i.port == info.port)
					return true;
			return false;
		}

		if (isClosed)
			onerror("Host is closed");
		else {
			exclude = exclude ?? [];
			for (client in clients)
				if (!ex(client.remote))
					client.send(message);
		}
	}

	function process():Void {
		while (!isClosed)
			if (!tick())
				break;
		try {
			for (connection in clients)
				closeClient(connection);
			if (onclose != null)
				onclose();
			isClosed = true;
			socket.close();
		} catch (e)
			if (onerror != null)
				onerror('Failed to close host: ${e.message}');
	}

	function handleClient(socket:Socket):Void {
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

			client.process();
		} catch (e) {
			onerror("WebSocket handleClient onerror: " + e.message);
		}
	}

	function closeClient(client:C) {
		clients.remove(client);
		onClientClose(client);
		client.close();
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
