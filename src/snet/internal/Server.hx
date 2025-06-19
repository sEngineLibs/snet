package snet.internal;

#if (nodejs || sys)
import haxe.Exception;
import haxe.Constraints;
import haxe.io.Bytes;
import sasync.Lazy;
import sasync.Async;
import snet.Net;
import snet.internal.Socket;
import snet.internal.Client;

private typedef ClientConstructor = (uri:URI, ?connect:Bool, ?certificate:Certificate) -> Void;

#if !macro
@:build(ssignals.Signals.build())
#end
@:generic
class Server<T:Constructible<ClientConstructor> & Client> extends Client {
	public var limit(default, null):Int;
	public var clients(default, null):Array<T> = [];

	@:signal function clientOpened(client:T):Void;

	@:signal function clientClosed(client:T):Void;

	public function new(uri:URI, limit:Int = 10, open:Bool = true, ?cert:Certificate) {
		super(uri, false, cert);
		local = remote;
		remote = null;
		this.limit = limit;

		if (open)
			this.open();
	}

	function handleClient(client:T) {}

	@async override function connect() {}

	public function open() {
		return Async.background(() -> if (isClosed) {
			socket = new Socket();
			try {
				socket.bind(local);
				socket.listen(limit);
				isClosed = false;
				logger.name = 'SERVER $local';
				logger.debug("Opened");
				opened();
				process();
			} catch (e) {
				logger.error('Failed to open: $e');
				socket.close();
			}
		});
	}

	override function send(data:Bytes) {
		broadcast(data);
	}

	public function broadcast(data:Bytes, ?exclude:Array<T>) {
		if (!isClosed) {
			exclude = exclude ?? [];
			for (client in clients)
				if (!exclude.contains(client))
					client.send(data);
		} else
			logger.error("Not open");
	}

	override function closeClient() {
		for (client in clients.iterator())
			closeServerClient(client);
	}

	override function tick() {
		try {
			var conn = socket.accept();
			if (conn != null) {
				var client = new T(conn.peer.info.toString(), false, certificate);
				client.socket = conn;
				client.local = conn.host.info;
				client.logger.name = 'HANDLER ${client.local} - ${client.remote}';
				client.isClosed = false;
				try {
					handleClient(client);
					client.onClosed(() -> {
						clients.remove(client);
						clientClosed(client);
					});
					clients.push(client);
					clientOpened(client);
					client.send(Bytes.ofString("hi"));
					client.process();
				} catch (e) {}
			}
		} catch (e) {
			if (e.message.toLowerCase().indexOf("interrupted") == -1) {
				logger.error(e.message);
				return false;
			}
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
