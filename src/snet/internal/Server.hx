package snet.internal;

#if (nodejs || sys)
import haxe.Exception;
import haxe.Constraints;
import haxe.io.Bytes;
import snet.Net;
import snet.internal.Socket;
import snet.internal.Client;

private typedef ClientConstructor = (uri:URI, ?connect:Bool, ?process:Bool, ?certificate:Certificate) -> Void;

#if !macro
@:build(ssignals.Signals.build())
#end
@:generic
abstract class Server<T:Constructible<ClientConstructor> & Client> extends Client {
	public var limit(default, null):Int;
	public var clients(default, null):Array<T> = [];

	@:signal function clientOpened(client:T):Void;

	@:signal function clientClosed(client:T):Void;

	public function new(uri:URI, limit:Int = 10, open:Bool = true, process:Bool = true, ?cert:Certificate) {
		super(uri, false, cert);
		local = remote;
		remote = null;
		this.limit = limit;

		if (open)
			this.open(process);
	}

	abstract function handleClient(client:T):Void;

	public function open(process:Bool = true):Void {
		if (!isClosed)
			throw new NetError("Already open");
		// socket = isSecure ? new SecureSocket(certificate) : new Socket();
		socket = new Socket();
		try {
			socket.bind(local.host, local.port);
			socket.listen(limit);
			isClosed = false;
			logger.name = 'SERVER $local';
			logger.debug("Opened");
			opened();
			if (process)
				this.process();
		} catch (e) {
			logger.error('Failed to open: $e');
			socket.close();
			throw e;
		}
	}

	override function send(data:Bytes) {
		broadcast(data);
	}

	public function broadcast(data:Bytes, ?exclude:Array<T>):Void {
		if (isClosed)
			throw new NetError("Not open");
		if (exclude != null && exclude.length > 0)
			for (client in clients)
				if (!exclude.contains(client))
					client.send(data);
				else
					for (client in clients)
						client.send(data);
	}

	function connectClient():Void {
		throw new NetError("Can't connect server");
	}

	function closeClient() {
		for (client in clients)
			closeServerClient(client);
	}

	function receive(data:Bytes) {}

	override function tick() {
		var conn = socket.accept();
		if (conn != null) {
			var client = new T(conn.peer.info.toString(), false, false, certificate);
			client.socket = conn;
			client.local = conn.host.info;
			client.logger.name = 'HANDLER ${client.local} - ${client.remote}';
			client.isClosed = false;
			// if (isSecure && certificate.verify)
			// 	cast(client.socket, SecureSocket).handshake();
			handleClient(client);
			client.onClosed(() -> {
				clients.remove(client);
				clientClosed(client);
			});
			clients.push(client);
			logger.debug('New client: ${client.remote}');
			clientOpened(client);
			client.process();
		}
		return true;
	}

	function closeServerClient(client:T):Void {
		clients.remove(client);
		clientClosed(client);
		client.close();
	}
}
#end
