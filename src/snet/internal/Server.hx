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

	@async function receive(data):Void {}

	@async function connectClient():Void {}

	@async override function connect():Void {
		throw new ServerError("Can't connect server");
	}

	@async public function open():Void {
		try {
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
		if (socket != null) {
			if (@await handleClient(socket)) {
				var peer = socket.peer;
				var host = socket.host;
				var client = new T(null, null, false, certificate);
				client.socket = socket;
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
			try {
				@await cast(socket, SecureSocket).handshake();
			} catch (e) {
				error(e);
				return false;
			}
		return true;
	}

	@async function closeServerClient(client:T):Void {
		clients.remove(client);
		clientClosed(client);
		client.close();
	}
}
