// package snet.ws;

// #if js
// @:forward()
// @:forward.new
// extern abstract WebSocketClient(js.html.WebSocket) {
// 	public var onopen(get, set):() -> Void;
// 	public var onerror(get, set):Dynamic->Void;
// 	public var onmessage(get, set):Message->Void;
// 	public var onclose(get, set):() -> Void;

// 	inline function get_onopen() {
// 		return cast this.onopen;
// 	}

// 	inline function set_onopen(value:() -> Void) {
// 		this.onopen = value;
// 		return onopen;
// 	}

// 	inline function get_onerror() {
// 		return cast this.onerror;
// 	}

// 	inline function set_onerror(value:Dynamic->Void) {
// 		this.onerror = value;
// 		return onerror;
// 	}

// 	inline function get_onmessage() {
// 		return cast this.onmessage;
// 	}

// 	inline function set_onmessage(value:(message:Message) -> Void) {
// 		this.onmessage = value;
// 		return onmessage;
// 	}

// 	inline function get_onclose() {
// 		return cast this.onclose;
// 	}

// 	inline function set_onclose(value:() -> Void) {
// 		this.onclose = value;
// 		return onclose;
// 	}
// }
// #elseif sys
// import haxe.io.Bytes;
// import haxe.crypto.Sha1;
// import haxe.crypto.Base64;
// import snet.http.Http;
// import snet.internal.Socket;
// import snet.internal.Client;
// import snet.ws.WebSocket;

// using StringTools;

// class WebSocketClient extends Client {
// 	var key:String;

// 	@:signal function message(msg:Message);

// 	public function new(host:String, port:Int, connect:Bool = true):Void {
// 		super(host, port, parseURL('$host:$port'), connect);
// 	}

// 	@async override function close():Void {
// 		if (isClosed)
// 			error(new WebSocketError("Client is not connected"));
// 		@await WebSocket.sendFrame(socket, Bytes.ofString("close"), Close);
// 		isClosed = true;
// 	}

// 	overload extern inline function send(message:Message) {
// 		return switch message {
// 			case Text(text):
// 				send(text);
// 			case Binary(data):
// 				send(data);
// 		}
// 	}

// 	overload extern inline function send(text:String) {
// 		return WebSocket.sendFrame(socket, Bytes.ofString(text), Text);
// 	}

// 	overload extern override inline function send(data:Bytes) {
// 		return WebSocket.sendFrame(socket, data, Binary);
// 	}

// 	public function ping() {
// 		return WebSocket.sendFrame(socket, Bytes.ofString("ping-" + Std.string(Math.random())), Ping);
// 	}

// 	@async function connectClient() {
// 		var err = @await handshake();
// 		if (err != null)
// 			throw new WebSocketError('Handshake failed: $err');
// 	}

// 	@async function closeClient() {}

// 	function receive(data:Bytes) {
// 		var frame = WebSocket.readFrame(data);
// 		switch frame.opcode {
// 			case Text:
// 				message(Text(frame.data.toString()));
// 			case Binary:
// 				message(Binary(frame.data));
// 			case Close:
// 				close();
// 			case Ping:
// 				WebSocket.sendFrame(socket, frame.data, Pong);
// 			case Pong:
// 				null;
// 			case Continuation:
// 				null;
// 		}
// 	}

// 	@async function handshake():String {
// 		// ws key
// 		var b = Bytes.alloc(16);
// 		for (i in 0...16)
// 			b.set(i, Std.random(255));
// 		key = Base64.encode(b);

// 		var resp = @await Http.request(remote, {
// 			headers: [
// 				"Host" => remote,
// 				"User-Agent" => "haxe",
// 				"Sec-Websocket-Key" => key,
// 				"Sec-Websocket-Version" => "13",
// 				"Upgrade" => "websocket",
// 				"Connection" => "Upgrade",
// 				"Pragma" => "no-cache",
// 				"Cache-Control" => "no-cache",
// 				"Origin" => local
// 			]
// 		}, "POST", 10, socket, true);

// 		if (resp == null)
// 			return 'No response from ${remote.host}';
// 		else
// 			return processHandshake(resp);
// 	}

// 	function processHandshake(resp:Response):String {
// 		if (resp.error != null)
// 			return resp.error;
// 		else {
// 			if (resp.status != 101)
// 				return resp.headers.get("X_WEBSOCKET_REJECT_REASON");
// 			var secKey = resp.headers.get("SEC_WEBSOCKET_ACCEPT");
// 			if (secKey != wsKey(key))
// 				return "Incorrect 'Sec-WebSocket-Accept' header value";
// 		}
// 		return null;
// 	}

// 	function parseURL(url:String):Bool {
// 		var uriRegExp = ~/^(\w+?):\/\/([\w\.-]+)(:(\d+))?(\/.*)?$/;

// 		if (!uriRegExp.match(url))
// 			throw new WebSocketError('"$url" does not match websocket uri');

// 		var secure = false;
// 		var proto = uriRegExp.matched(1);
// 		if (proto == "wss") {
// 			#if (java || cs)
// 			throw new WebSocketError("Secure sockets are not supported on this platform");
// 			#else
// 			remote.port = 443;
// 			secure = true;
// 			#end
// 		} else if (proto == "ws")
// 			remote.port = 80;
// 		else
// 			throw new WebSocketError('Unknown protocol $proto');

// 		remote.host = uriRegExp.matched(2);
// 		remote.port = Std.parseInt(uriRegExp.matched(4));

// 		return secure;
// 	}

// 	inline function wsKey(key:String):String {
// 		return Base64.encode(Sha1.make(Bytes.ofString(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')));
// 	}
// }
// #end
