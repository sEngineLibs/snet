package snet.ws;

import snet.Net.NetClient;
import haxe.io.Bytes;
#if js
@:forward()
@:forward.new
extern abstract WebSocketClient(js.html.WebSocket) {
	public var onopen(get, set):() -> Void;

	public var onerror(get, set):() -> Void;

	public var onmessage(get, set):(message:Message) -> Void;

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

	inline function set_onerror(value:() -> Void) {
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
import haxe.crypto.Sha1;
import haxe.crypto.Base64;
import snet.Requests;
import snet.ws.WebSocket;

using StringTools;

class WebSocketClient extends NetClient<Message> {
	var key:String;
	var additionalHeaders:Map<String, String> = [];

	/**
		The binary data type used by the connection.
	**/
	var binaryType:BinaryType;

	/**
		The number of bytes of queued data.
	**/
	public var bufferedAmount(default, null):Int;

	/**
		The extensions selected by the server.
	**/
	public var extensions(default, null):String;

	/**
		The sub-protocol selected by the server.
	**/
	public var protocol(default, null):String;

	/**
		The current state of the connection.
	**/
	public var readyState(default, null):Int;

	public function new(host:String, port:Int, immediateConnect:Bool = true):Void {
		super(host, port, false);
		if (parseURL('$host:$port')) {
			onopen = () -> if (!sendHandshake()) close();
			if (immediateConnect)
				connect();
		}
	}

	override function close():Void {
		WebSocket.sendFrame(socket, Bytes.ofString("close"), Close);
		super.close();
	}

	extern overload inline function send(text:String) {
		return super.send(WebSocket.writeFrame(Bytes.ofString(text), Binary, true, true));
	}

	extern overload override inline function send(data:Bytes) {
		return super.send(WebSocket.writeFrame(data, Binary, true, true));
	}

	@async public function ping():Bool {
		WebSocket.sendFrame(socket, Bytes.ofString("ping-" + Std.string(Math.random())), Ping);
	}

	@async function receiveData(data:Bytes):Void {
		var frame = WebSocket.readFrame(data);
		switch frame.opcode {
			case Text:
				onmessage(Text(frame.data.toString()));
			case Binary:
				onmessage(Binary(frame.data));
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

	function sendHandshake() {
		// ws key
		var b = Bytes.alloc(16);
		for (i in 0...16)
			b.set(i, Std.random(255));

		var resp = Requests.customRequest(remote, {
			headers: [
				"Host" => remote,
				"User-Agent" => "haxe",
				"Sec-Websocket-Key" => Base64.encode(b),
				"Sec-Websocket-Version" => "13",
				"Upgrade" => "websocket",
				"Connection" => "Upgrade",
				"Pragma" => "no-cache",
				"Cache-Control" => "no-cache",
				"Origin" => local
			]
		}, false, socket, false);

		if (resp == null) {
			onerror('Handshake failed: no request from ${socket.host().host}');
			close();
		}
		if (processHandshake(resp)) {
			if (onopen != null)
				onopen();
			return true;
		} else {
			onerror('Failed to connect socket, invalid handshake response');
			close();
		}
		return false;
	}

	function processHandshake(resp:Response) {
		if (resp.status != 101) {
			onerror(resp.headers.get("X_WEBSOCKET_REJECT_REASON"));
			return false;
		}
		var secKey = resp.headers.get("SEC_WEBSOCKET_ACCEPT");
		if (secKey != wsKey(key)) {
			onerror("Error during WebSocket handshake: Incorrect 'Sec-WebSocket-Accept' header value");
			return false;
		}
		return true;
	}

	function parseURL(url:String) {
		var uriRegExp = ~/^(\w+?):\/\/([\w\.-]+)(:(\d+))?(\/.*)?$/;

		if (!uriRegExp.match(url)) {
			onerror('Uri not matching websocket uri "$url"');
			return false;
		}

		var proto = uriRegExp.matched(1);
		if (proto == "wss") {
			#if (java || cs)
			return false;
			#else
			local.port = 443;
			this.socket = new sys.ssl.Socket();
			#end
		} else if (proto == "ws")
			local.port = 80;
		else {
			onerror('Unknown protocol $proto');
			return false;
		}

		local.host = uriRegExp.matched(2);
		var parsedPort = Std.parseInt(uriRegExp.matched(4));
		if (parsedPort > 0)
			local.port = parsedPort;

		url = uriRegExp.matched(5);
		if (url == null || url.length == 0)
			url = "/";
		return true;
	}

	inline function wsKey(key:String):String {
		return Base64.encode(Sha1.make(Bytes.ofString(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')));
	}
}
#end
