package snet.internal;

import haxe.Exception;
import haxe.Constraints;
import haxe.io.Bytes;
import snet.Net;
import snet.internal.Socket;

class ServerError extends Exception {}
private typedef ClientConstructor = (uri:URI, ?connect:Bool, ?process:Bool, ?certificate:Certificate) -> Void;

#if !macro
@:build(ssignals.Signals.build())
#end
@:generic
class Server<T:Constructible<ClientConstructor> & Client> extends Client {
	public var limit(default, null):Int;
	public var clients(default, null):Array<T> = [];

	public function new(uri:URI, limit:Int = 10, open:Bool = true, process:Bool = true, ?cert:Certificate) {
		super(uri, false, cert);

		local = remote;
		remote = null;
		this.limit = limit;

		if (open)
			this.open(process);
	}

	@:signal function clientOpened(client:T):Void;

	@:signal function clientClosed(client:T):Void;

	override function connect(process:Bool = true):Void {
		throw new ServerError("Can't connect server");
	}

	public function open(process:Bool = true):Void {
		if (!isClosed)
			throw new ServerError("Server is already open");
		socket = isSecure ? new SecureSocket(certificate) : new Socket();
		try {
			socket.bind(new sys.net.Host(local.host), local.port);
			socket.listen(limit);
			isClosed = false;
			log("Opened");
			// opened();
			if (process)
				this.process();
		} catch (e) {
			socket.close();
			throw e;
		}
	}

	override function send(data:Bytes) {
		broadcast(data);
	}

	public function broadcast(data:Bytes, ?exclude:Array<T>):Void {
		if (isClosed)
			throw new ServerError("Server is not open");
		if (exclude != null && exclude.length > 0)
			for (client in clients)
				if (!exclude.contains(client))
					client.send(data);
				else
					for (client in clients)
						client.send(data);
	}

	override function closeClient() {
		for (client in clients)
			closeServerClient(client);
	}

	override function tick() {
		var conn = socket.accept();
		if (conn != null) {
			var client = new T(conn.peer.info.toString(), false, false, certificate);
			client.socket = conn;
			client.local = conn.host.info;
			client.isClosed = false;
			handleClient(client, () -> {
				client.onClosed(() -> {
					clients.remove(client);
					clientClosed(client);
				});
				clients.push(client);
				clientOpened(client);
				client.process();
			});
		}
		return true;
	}

	function handleClient(client:T, callback:Void->Void) {
		if (isSecure && certificate.verify)
			cast(client.socket, SecureSocket).handshake();
		callback();
	}

	function closeServerClient(client:T):Void {
		clients.remove(client);
		clientClosed(client);
		client.close();
	}

	override function log(msg:String) {
		slog.Log.debug('SERVER $local | $msg');
	}
}
