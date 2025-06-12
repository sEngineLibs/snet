package snet.ws;

import haxe.io.Bytes;
import snet.ws.WebSocket;
#if (nodejs || sys)
import haxe.crypto.Base64;
import snet.http.Http;
import snet.internal.Client;

using StringTools;

#if !macro
@:build(ssignals.Signals.build())
#end
class WebSocketClient extends Client {
	@:signal function bytes(bytes:Bytes);

	@:signal function text(text:String);

	overload extern inline function send(text:String) {
		WebSocket.sendFrame(socket, Bytes.ofString(text), Text);
	}

	overload extern override inline function send(data:Bytes) {
		WebSocket.sendFrame(socket, data, Binary);
	}

	function ping() {
		WebSocket.sendFrame(socket, Bytes.ofString("ping-" + Std.string(Math.random())), Ping);
	}

	override function connectClient() {
		try {
			handshake();
		} catch (e) {
			logger.error('Handshake failed: $e');
			throw e;
		}
	}

	override function closeClient() {
		WebSocket.sendFrame(socket, Bytes.ofString("close"), Close);
	}

	override function receive(data:Bytes) {
		var frame = WebSocket.readFrame(data);
		switch frame.opcode {
			case Text:
				text(frame.data.toString());
			case Binary:
				bytes(frame.data);
			case Close:
				@await close();
			case Ping:
				WebSocket.sendFrame(socket, frame.data, Pong);
			case Pong:
				null;
			case Continuation:
				null;
		}
	}

	function handshake() {
		// ws key
		var b = Bytes.alloc(16);
		for (i in 0...16)
			b.set(i, Std.random(255));
		var key = Base64.encode(b);

		var resp = Http.customRequest(socket, false, {
			headers: [
				HOST => remote,
				USER_AGENT => "haxe",
				SEC_WEBSOCKET_KEY => key,
				SEC_WEBSOCKET_VERSION => "13",
				UPGRADE => "websocket",
				CONNECTION => "Upgrade",
				PRAGMA => "no-cache",
				CACHE_CONTROL => "no-cache",
				ORIGIN => local
			]
		}, 1.0);

		if (resp == null)
			throw 'No response from ${remote.host}';
		else
			processHandshake(resp, key);
	}

	function processHandshake(resp:HttpResponse, key:String) {
		if (resp.error != null)
			throw resp.error;
		else {
			if (resp.status != 101)
				throw resp.headers.get(X_WEBSOCKET_REJECT_REASON) ?? resp.statusText;
			var secKey = resp.headers.get(SEC_WEBSOCKET_ACCEPT);
			if (secKey != WebSocket.computeKey(key))
				throw "Incorrect 'Sec-WebSocket-Accept' header value";
		}
	}
}
#elseif js
import js.html.WebSocket as Socket;
import slog.Log;
import sasync.Lazy;

#if !macro
@:build(ssignals.Signals.build())
#end
class WebSocketClient {
	var socket:Socket;
	var logger:Logger = new Logger("CLIENT");

	public var isClosed(default, null):Bool = true;

	/**
		The other side of a connected socket.
	**/
	public var remote(default, null):HostInfo;

	@:signal function bytes(bytes:Bytes);

	@:signal function text(text:String);

	@:signal function opened();

	@:signal function closed();

	public function new(uri:URI, connect:Bool = true) {
		if (uri == null)
			throw new NetError('Invalid URI');

		if (!["ws", "wss"].contains(uri.proto))
			throw new NetError('Invalid protocol: ${uri.proto}');

		remote = uri.host;

		if (connect)
			this.connect();
	}

	public function connect() {
		return new Lazy((resolve, reject) -> {
			if (!isClosed)
				throw new NetError("Already connected");
			socket = new Socket('ws://$remote');
			socket.onerror = e -> {
				logger.error(e);
				reject(new NetError(e));
			}
			socket.onopen = () -> {
				isClosed = false;
				socket.onmessage = m -> text(m);
				socket.onclose = () -> isClosed = true;
				logger.name = 'CLIENT $remote';
				logger.debug("Connected");
				opened();
				resolve();
			}
		}, false);
	}

	public function close() {
		return new Lazy((resolve, reject) -> {
			if (isClosed)
				throw new NetError("Not connected");
			socket.close();
			socket.onclose = () -> {
				isClosed = true;
				resolve();
			}
		}, false);
	}

	overload extern inline function send(text:String) {
		if (isClosed)
			throw new NetError("Not connected");
		socket.send(text);
		logger.info('Sent ${Bytes.ofString(text).length} bytes of data');
	}

	overload extern inline function send(data:Bytes) {
		socket.send(data.getData());
	}

	function toString() {
		return logger.name;
	}
}
#end
