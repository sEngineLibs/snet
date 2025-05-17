package snet;

#if sys
import sys.net.Socket;
import haxe.Constraints;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import sasync.Promise;

@:forward.new
@:forward(host, port)
abstract HostInfo(HostInfoData) {
	@:to
	public inline function toString():String {
		return '${this.host}:${this.port}';
	}
}

class HostInfoData {
	public var host:String;
	public var port:Int;

	public inline function new(host:String, port:Int) {
		this.host = host;
		this.port = port;
	}
}

abstract class NetClient<M> {
	var socket:Socket;

	public var isClosed(default, null):Bool = true;

	public var local(default, null):HostInfo;
	public var remote(default, null):HostInfo;

	public var onopen:() -> Void = () -> {};
	public var onerror:(message:String) -> Void = _ -> {};
	public var onmessage:(message:M) -> Void = _ -> {};
	public var onclose:() -> Void = () -> {};

	public function new(host:String, port:Int, immediateConnect = true) {
		remote = new HostInfo(host, port);
		if (immediateConnect)
			connect();
	}

	@async public function connect():Void {
		if (!isClosed)
			onerror("Client is already running");
		try {
			socket = new Socket();
			socket.setBlocking(true);
			socket.connect(new sys.net.Host(remote.host), remote.port);
			var host = socket.host();
			local = new HostInfo(Std.string(host.host), host.port);

			isClosed = false;
			onopen();

			@await process();
		} catch (e) {
			onerror('Failed to connect to $remote: ${e.message}');
			try
				socket.close()
			catch (_) {}
		}
	}

	public function close():Void {
		isClosed = true;
	}

	@async public function send(data:Bytes):Void {
		if (isClosed)
			onerror("Client is closed");
		else {
			socket.output.writeBytes(data, 0, data.length);
			socket.output.flush();
		}
	}

	abstract function receiveData(data:Bytes):Promise<Void>;

	@async function process():Void {
		while (!isClosed)
			if (! @await tick())
				break;
		try {
			socket.close();
			isClosed = true;
			onclose();
		} catch (e)
			onerror('Error closing socket: ${e.message}');
	}

	@async function tick():Bool {
		static final bufSize = 1024;

		if (Socket.select([socket], [], [], 0.01).read.length > 0)
			try {
				var buf = Bytes.alloc(1024);
				var data = new BytesBuffer();
				while (true) {
					var len = socket.input.readBytes(buf, 0, bufSize);
					if (len > 0) {
						data.addBytes(buf, 0, len);
						if (len < bufSize)
							break;
					} else
						return null;
				}
				if (data.length == 0)
					return false;
				@await receiveData(data.getBytes());
			} catch (e) {
				onerror('Failed to tick: ${e.message}');
				return false;
			}
		return true;
	}
}

@:generic
abstract class NetHost<M, C:Constructible<(String, Int, Bool) -> Void> & NetClient<M>> extends NetClient<M> {
	public var clients:Array<C> = [];
	public var limit(default, null):Int;

	public var onClientOpen:(connection:C) -> Void = _ -> {};
	public var onClientMessage:(connection:C, message:M) -> Void = (_, _) -> {};
	public var onClientClose:(connection:C) -> Void = _ -> {};

	public function new(host:String, port:Int, immediateStart:Bool = false, limit:Int = 10) {
		super(host, port, false);
		local = remote;
		remote = null;
		this.limit = limit;
		if (immediateStart)
			start();
	}

	@async public function start():Void {
		if (!isClosed)
			onerror("Socket is not closed");
		else {
			socket = new Socket();
			try {
				socket.setBlocking(true);
				socket.bind(new sys.net.Host(local.host), local.port);
				socket.listen(limit);
				isClosed = false;

				if (onopen != null)
					onopen();
				@await process();
			} catch (e) {
				if (onerror != null)
					onerror('Failed to start server on $local: ${e.message}');
				socket.close();
				return;
			}
		}
	}

	@async override function connect():Void {
		onerror("Can't connect host");
	}

	@async override function process():Void {
		while (!isClosed)
			if (! @await tick())
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

	@async override function send(data:Bytes):Void {
		if (isClosed)
			onerror("Host is closed");
		else
			for (client in clients)
				client.send(data);
	}

	@async public function broadcast(data:Bytes, ?exclude:Array<HostInfo>):Void {
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
					client.send(data);
		}
	}

	@async final function receiveData(data:Bytes):Void {
		return;
	}

	@async override function tick():Bool {
		try {
			if (Socket.select([socket], [], [], 0.01).read.length > 0)
				@await handleClient(socket.accept());
			return true;
		} catch (e)
			if (onerror != null)
				onerror('Failed to tick: ${e.message}');
		return false;
	}

	@async function handleClient(socket:Socket):Void {
		if (socket != null) {
			var peer = socket.peer();
			var client = new C(Std.string(peer.host), peer.port, false);
			client.isClosed = false;
			client.socket = socket;
			client.local = local;
			client.onmessage = m -> onClientMessage(client, m);
			client.onclose = () -> {
				clients.remove(client);
				onClientClose(client);
			};
			clients.push(client);
			onClientOpen(client);
			@await client.process();
		}
	}

	function closeClient(client:C) {
		clients.remove(client);
		onClientClose(client);
		client.close();
	}
}
#end
