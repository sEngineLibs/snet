package snet.ws;

#if js
@:forward()
@:forward.new
extern abstract WebSocketClient(js.html.WebSocket) {
	public var onopen(get, set):() -> Void;
	public var onerror(get, set):Dynamic->Void;
	public var onmessage(get, set):Message->Void;
	public var onclose(get, set):() -> Void;

	inline function get_onopen() {
		return cast this.onopen;
	}

	inline function set_onopen(value:() -> Void) {
		this.onopen = value;
		return onopen;
	}

	inline function get_onerror() {
		return cast this.onerror;
	}

	inline function set_onerror(value:Dynamic->Void) {
		this.onerror = value;
		return onerror;
	}

	inline function get_onmessage() {
		return cast this.onmessage;
	}

	inline function set_onmessage(value:(message:Message) -> Void) {
		this.onmessage = value;
		return onmessage;
	}

	inline function get_onclose() {
		return cast this.onclose;
	}

	inline function set_onclose(value:() -> Void) {
		this.onclose = value;
		return onclose;
	}
}
#elseif sys
import haxe.io.Bytes;
import haxe.crypto.Base64;
import snet.http.Requests;
import snet.internal.Client;
import snet.internal.Socket;
import snet.ws.WebSocket;

using StringTools;

class WebSocketClient extends Client {
	var key:String;

	@:signal function message(msg:Message);

	public function new(uri:String, connect:Bool = true, process:Bool = true, ?certificate:Certificate):Void {
		super(uri, connect, process, certificate);
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
		WebSocket.sendFrame(socket, Bytes.ofString(text), Text);
	}

	overload extern override inline function send(data:Bytes) {
		WebSocket.sendFrame(socket, data, Binary);
	}

	public function ping() {
		return WebSocket.sendFrame(socket, Bytes.ofString("ping-" + Std.string(Math.random())), Ping);
	}

	override function connectClient() {
		try {
			handshake();
		} catch (e)
			throw new WebSocketError('Handshake failed: $e');
	}

	override function closeClient() {
		WebSocket.sendFrame(socket, Bytes.ofString("close"), Close);
	}

	@:slot(data)
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

		var resp = Requests.customRequest(this, false, {
			headers: [
				"Host" => remote,
				"User-Agent" => "snet",
				"Sec-Websocket-Key" => key,
				"Sec-Websocket-Version" => "13",
				"Upgrade" => "websocket",
				"Connection" => "Upgrade",
				"Pragma" => "no-cache",
				"Cache-Control" => "no-cache",
				"Origin" => local
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
				throw resp.headers.get("X_WEBSOCKET_REJECT_REASON");
			var secKey = resp.headers.get("SEC_WEBSOCKET_ACCEPT");
			if (secKey != WebSocket.computeWebSocketKey(key))
				throw "Incorrect 'Sec-WebSocket-Accept' header value";
		}
	}
}
#end
