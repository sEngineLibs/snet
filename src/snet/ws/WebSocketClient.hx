package snet.ws;

import haxe.io.Bytes;
import snet.Net;
import snet.ws.WebSocket;
#if (nodejs || sys)
import haxe.crypto.Base64;
import snet.http.Http;
import snet.internal.Socket;
import snet.internal.Client;

using StringTools;

#if !macro
@:build(ssignals.Signals.build())
#end
class WebSocketClient extends Client {
	var key:String;

	@:signal function message(msg:Message);

	overload extern inline function send(message:Message) {
		return switch message {
			case Text(text):
				send(text);
			case Binary(data):
				send(data);
		}
	}

	overload extern inline function send(text:String) {
		WebSocket.sendFrame(socket, Bytes.ofString(text), Text);
	}

	overload extern override inline function send(data:Bytes) {
		WebSocket.sendFrame(socket, data, Binary);
	}

	function ping() {
		WebSocket.sendFrame(socket, Bytes.ofString("ping-" + Std.string(Math.random())), Ping);
	}

	function connectClient() {
		try {
			handshake();
		} catch (e)
			throw new WebSocketError('Handshake failed: $e');
	}

	function closeClient() {
		WebSocket.sendFrame(socket, Bytes.ofString("close"), Close);
	}

	function receive(data:Bytes) {
		var frame = WebSocket.readFrame(data);
		switch frame.opcode {
			case Text:
				message(Text(frame.data.toString()));
			case Binary:
				message(Binary(frame.data));
			case Close:
				close();
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
		key = Base64.encode(b);

		logger.debug('Handshaking with key $key');
		var resp = Http.customRequest(socket, false, {
			headers: [
				HOST => remote,
				USER_AGENT => "snet",
				SEC_WEBSOCKET_KEY => key,
				SEC_WEBSOCKET_VERSION => "13",
				UPGRADE => "websocket",
				CONNECTION => "Upgrade",
				PRAGMA => "no-cache",
				CACHE_CONTROL => "no-cache",
				ORIGIN => local
			]
		});

		if (resp == null)
			throw 'No response from ${remote.host}';
		else
			processHandshake(resp);
	}

	function processHandshake(resp:HttpResponse) {
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

	@:signal function message(msg:Message);

	@:signal function opened();

	@:signal function closed();

	public function new(uri:URI, connect:Bool = true, process:Bool = true) {
		if (uri == null)
			throw new NetError('Invalid URI');

		if (!["ws", "wss"].contains(uri.proto))
			throw new NetError('Invalid protocol: ${uri.proto}');

		remote = uri.host;

		if (connect)
			this.connect(process);
	}

	public function connect(process:Bool = true):Void {
		if (!isClosed)
			throw new NetError("Already connected");
		socket = new Socket('ws://$remote');
		socket.onerror = e -> logger.error(e);
		socket.onopen = () -> {
			logger.name = 'CLIENT $remote';
			isClosed = false;
			logger.debug("Connected");
			opened();
			if (process)
				this.process();
		}
	}

	public function close():Void {
		if (isClosed)
			throw new NetError("Not connected");
		socket.close();
	}

	overload extern inline function send(message:Message) {
		return switch message {
			case Text(text):
				send(text);
			case Binary(data):
				send(data);
		}
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

	function process():Void {
		socket.onmessage = m -> message(Text(m));
		socket.onclose = () -> isClosed = true;
	}

	function toString() {
		return logger.name;
	}
}
#end
