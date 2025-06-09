package hx.ws.nodejs;

#if node
import sys.net.Host;
import haxe.io.Bytes;
import js.node.Net;
import js.node.Buffer;
import js.node.net.Server;
import js.node.net.Socket;

class Socket {
	static var connections:Array<Socket> = [];

	public static function select(read:Array<Socket>, write:Array<Socket>, others:Array<Socket>,
			?timeout:Float):{read:Array<Socket>, write:Array<Socket>, others:Array<Socket>} {
		if (write?.length > 0 || others?.length > 0)
			throw "Not implemented";

		var ret = {
			read: [],
			write: [],
			others: []
		}
		for (c in connections)
			if (read.indexOf(c) != -1 && c.input.hasData == true)
				ret.read.push(c);

		return ret;
	}

	var socket:Socket;
	var server:Server;
	var host:Host;
	var port:Int;

	public var input(default, null):SocketInput;
	public var output(default, null):SocketOutput;

	public function new() {}

	function setSocket(s:Socket) {
		socket = s;
		input = new SocketInput(this);
		output = new SocketOutput(this);
	}

	var newConnections:Array<Socket> = [];

	function acceptConnection(socket:Socket) {
		socket.setTimeout(0);
		var nodeSocket = new Socket();
		nodeSocket.setSocket(socket);
		connections.push(nodeSocket);
		newConnections.push(nodeSocket);
	}

	public function accept() {
		if (newConnections.length == 0)
			throw "Blocking";
		return newConnections.pop();
	}

	public function listen(connections:Int):Void {
		if (server == null)
			throw "You must bind the Socket to an address!";
		server.listen({
			host: host.host,
			port: port,
			backlog: connections
		});
	}

	public function bind(host:Host, port:Int):Void {
		host = host;
		port = port;
		if (server == null)
			server = Net.createServer(acceptConnection);
	}

	public function setBlocking(blocking:Bool) {}

	public function setTimeout(timeout:Int) {}

	public function close() {
		server?.close();
		socket?.destroy();
	}
}

@:access(hx.ws.nodejs.Socket)
class SocketInput {
	var socket:Socket;
	var buffer:Buffer = null;

	public var hasData = false;

	public function new(socket:Socket) {
		socket = socket;
		socket.socket.on("data", onData);
	}

	function onData(data:Any) {
		var a = [];
		if (buffer != null)
			a.push(buffer);
		a.push(Buffer.from(data));
		buffer = Buffer.concat(a);
		hasData = true;
	}

	public function readBytes(s:Bytes, pos:Int, len:Int):Int {
		if (buffer == null)
			return 0;
		var n = buffer.length;
		if (n > len)
			n = len;
		if (len > n)
			len = n;
		var part = buffer.slice(0, len);
		var remain = null;
		if (buffer.length > len)
			remain = buffer.slice(len);
		var src = part.hxToBytes();
		s.blit(pos, src, 0, len);
		hasData = (remain != null);
		buffer = remain;
		return n;
	}
}

@:access(hx.ws.nodejs.Socket)
class SocketOutput {
	var socket:Socket;
	var buffer:Buffer = null;

	public function new(socket:Socket) {
		this.socket = socket;
	}

	public function write(data:Bytes) {
		var a = [];
		if (buffer != null)
			a.push(buffer);
		a.push(Buffer.hxFromBytes(data));
		buffer = Buffer.concat(a);
	}

	public function flush() {
		socket.socket.write(buffer);
		buffer = null;
	}
}
#end
