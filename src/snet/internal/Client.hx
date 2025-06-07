package snet.internal;

import haxe.Exception;
import haxe.io.Bytes;

class ClientError extends Exception {}

#if !macro
@:build(ssignals.Signals.build())
@:autoBuild(ssignals.Signals.build())
#end
abstract class Client {
	var socket:Socket;

	public var secure(default, null):Bool;
	public var isClosed(default, null):Bool = true;

	/**
		Our side of a connected socket.
	**/
	public var local(default, null):HostInfo;

	/**
		The other side of a connected socket.
	**/
	public var remote(default, null):HostInfo;

	@:signal function opened();

	@:signal function closed();

	@:signal function error(err:Dynamic);

	public function new(host:String, port:Int, secure:Bool = false, connect:Bool = true):Void {
		this.secure = secure;
		socket = new Socket(secure);
		remote = new HostInfo(host, port);
		if (connect)
			this.connect();
	}

	@async abstract function connectClient():Void;

	@async abstract function closeClient():Void;

	@async abstract function receive(data:Bytes):Void;

	@async public function connect():Void {
		try {
			if (!isClosed)
				throw new ClientError("Client is already connected");
			@await socket.connect(new sys.net.Host(remote.host), remote.port);
			local = new HostInfo(socket.host.host.toString(), socket.host.port);
			@await connectClient();
			isClosed = false;
			opened();
			process();
		} catch (e) {
			error(e);
			@await socket.close();
		}
	}

	@async public function close():Void {
		if (isClosed)
			error(new ClientError("Client is not connected"));
		isClosed = true;
	}

	@async public function send(data:Bytes):Void {
		try {
			if ((@await Socket.select([], [socket], [], 1.0)).write.length > 0) {
				socket.output.write(data);
				socket.output.flush();
			}
		} catch (e)
			error(e);
	}

	@async function process():Void {
		if (@await tick())
			@await process();
		else {
			isClosed = true;
			try {
				@await closeClient();
				closed();
			} catch (e)
				error(e);
			@await socket.close();
		}
	}

	@async function tick():Bool {
		if (!isClosed)
			try {
				var data = @await socket.receive();
				if (data != null) {
					if (data.length > 0)
						receive(data);
					return true;
				}
			} catch (e)
				error(e);
		return false;
	}
}
