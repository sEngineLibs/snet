package snet.internal;

import haxe.Exception;
import haxe.Constraints;
import haxe.io.Bytes;
import sasync.Async;
import snet.internal.Socket;

class ServerError extends Exception {}
private typedef ClientConstructor = (String, Int, Bool, Certificate) -> Void;

#if !macro
@:build(ssignals.Signals.build())
#end
@:generic
abstract class Server<T:Constructible<ClientConstructor> & Client> extends Client {
	public var limit(default, null):Int;
	public var clients(default, null):Array<T> = [];

	public function new(host:String, port:Int, limit:Int = 10, open:Bool = true, ?cert:Certificate) {
		super(host, port, false, cert);
		local = new HostInfo(host, port);
		this.limit = limit;
		if (open)
			this.open();
	}

	@:signal function clientOpened(client:T):Void;

	@:signal function clientClosed(client:T):Void;

	@async override function connect():Void {
		throw new ServerError("Can't connect server");
	}

	@async public function open():Void {
		if (!isClosed)
			throw new ServerError("Server is already open");
		if (isSecure) {
			var secureSocket = new SecureSocket();
			secureSocket.setCA(certificate.cert);
			secureSocket.setCertificate(certificate.cert, certificate.key);
			secureSocket.setHostname(certificate.hostname);
			secureSocket.verifyCert = certificate.verify;
			socket = secureSocket;
		} else
			socket = new Socket();
		try {
			@await socket.bind(new sys.net.Host(local.host), local.port);
			@await socket.listen(limit);
			isClosed = false;
			log("Opened");
			opened();
			process();
		} catch (e) {
			@await socket.close();
			throw e;
		}
	}

	@async override function send(data:Bytes) {
		broadcast(data);
	}

	@async public function broadcast(data:Bytes, ?exclude:Array<T>):Void {
		if (isClosed)
			throw new ServerError("Server is not open");
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

	@async override function closeClient() {
		@await Async.gather([
			for (client in clients)
				closeServerClient(client)
		]);
	}

	@async override function tick() {
		var conn = @await socket.accept();
		if (conn != null) {
			if (@await handleClient(conn)) {
				var peer = conn.peer;
				var host = conn.host;
				var client = new T(null, null, false, certificate);
				client.socket = conn;
				client.remote = new HostInfo(peer.host.toString(), peer.port);
				client.local = new HostInfo(host.host.toString(), host.port);
				client.isClosed = false;
				client.onClosed(() -> {
					clients.remove(client);
					clientClosed(client);
				});

				clients.push(client);
				clientOpened(client);
				client.process();
			}
		}
		return true;
	}

	@async function handleClient(socket:Socket):Bool {
		if (isSecure && certificate.verify)
			@await cast(socket, SecureSocket).handshake();
		return true;
	}

	@async function closeServerClient(client:T):Void {
		clients.remove(client);
		clientClosed(client);
		client.close();
	}

	override function log(msg:String) {
		slog.Log.debug('SERVER $local | $msg');
	}
}
