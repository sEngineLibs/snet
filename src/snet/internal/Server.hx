package snet.internal;

import snet.internal.Socket.SysSocket;
import sys.thread.Thread;
import haxe.Exception;
import haxe.Constraints;
import haxe.io.Bytes;
import sasync.Async;
import sasync.Future;

class ServerError extends Exception {}
private typedef ClientConstructor = (String, Int, Bool, Bool) -> Void;

@:generic
abstract class Server<T:Constructible<ClientConstructor> & Client> extends Client {
	public var limit(default, null):Int;
	public var clients(default, null):Array<T> = [];

	public function new(host:String, port:Int, limit:Int = 10, secure:Bool = false, open:Bool = true) {
		super(null, null, secure, false);
		local = new HostInfo(host, port);
		this.limit = limit;
		if (open)
			this.open();
	}

	@:signal function clientOpened(client:T):Void;

	@:signal function clientClosed(client:T):Void;

	@async abstract function handleClient(socket:Socket):Bool;

	@async override function connect():Void {
		throw new ServerError("Can't connect server");
	}

	@async public function open():Void {
		try {
			if (!isClosed)
				throw(new ServerError("Server is already open"));
			@await socket.bind(new sys.net.Host(local.host), local.port);
			@await socket.listen(limit);
			isClosed = false;
			opened();
			process();
		} catch (e) {
			socket.close();
			error(e);
		}
	}

	@async override function send(data:Bytes) {
		broadcast(data);
	}

	@async public function broadcast(data:Bytes, ?exclude:Array<T>):Void {
		if (isClosed)
			error(new ServerError("Host is not open"));
		else {
			if (exclude != null && exclude.length > 0)
				@await Async.gather([
					for (client in clients)
						if (!exclude.contains(client)) client.send(data)
				]);
			else
				@await Async.gather([
					for (client in clients)
						client.send(data)
				]);
		}
	}

	@async function closeClient():Void {
		@await Async.gather([
			for (client in clients)
				closeServerClient(client)
		]);
	}

	@async override function tick() {
		var socket:Socket = @await socket.accept();
		var peer = socket.peer;

		if (@await handleClient(socket)) {
			var client = new T(peer.host.host, peer.port, secure, false);
			client.socket = socket;
			client.local = local;
			client.isClosed = false;
			client.onClosed(() -> {
				clients.remove(client);
				clientClosed(client);
			});

			clients.push(client);
			clientOpened(client);
			client.process();
		}

		return true;
	}

	@async function closeServerClient(client:T):Void {
		clients.remove(client);
		clientClosed(client);
		client.close();
	}
}
