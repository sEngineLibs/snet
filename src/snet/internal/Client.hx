package snet.internal;

#if (nodejs || sys)
import haxe.io.Bytes;
import slog.Log;
import sasync.Lazy;
import sasync.Async;
import snet.Net;
import snet.internal.Socket;

#if !macro
@:build(ssignals.Signals.build())
#end
class Client {
	var socket:Socket;
	var logger:Logger = new Logger("CLIENT");

	public var isClosed(default, null):Bool = true;
	public var isSecure(default, null):Bool;
	public var certificate(default, null):Certificate;

	/**
		Absolute uri of a client
	**/
	public var uri(default, null):URI;

	/**
		Local side of a client.
	**/
	public var local(default, null):HostInfo;

	/**
		Remote side of a client.
	**/
	public var remote(default, null):HostInfo;

	@:signal function opened();

	@:signal function closed();

	@:signal function data(data:Bytes);

	public function new(uri:URI, connect:Bool = true, ?cert:Certificate):Void {
		if (uri != null) {
			this.uri = uri;
			remote = uri.host;
			isSecure = uri.isSecure;
			certificate = cert;

			if (connect)
				this.connect();
		}
	}

	function receive(data:Bytes) {
		this.data(data);
	}

	function connectClient() {}

	function closeClient() {}

	public function connect() {
		return Async.background(() -> if (isClosed) {
			try {
				socket = new Socket();
				socket.connect(remote);
				isClosed = false;
				// socket.setBlocking(false);
				local = socket.host.info;
				logger.name = 'CLIENT $local - $remote';
				connectClient();
				logger.debug("Connected");
				opened();
				process();
			} catch (e) {
				logger.error('Failed to connect: $e');
				if (!isClosed) {
					socket.close();
					isClosed = true;
				}
			}
		});
	}

	public function close() {
		return new Lazy((resolve, reject) -> {
			if (!isClosed) {
				socket.close();
				isClosed = true;
			}
			resolve();
		}, false);
	}

	public function send(data:Bytes) {
		if (!isClosed)
			try {
				socket.output.write(data);
				socket.output.flush();
			} catch (e)
				logger.error('Failed to send data: $e');
	}

	function process() {
		Async.background(() -> {
			while (!isClosed)
				if (!tick())
					break;
			closeClient();
			if (!isClosed) {
				socket.close();
				isClosed = true;
			}
			logger.debug("Closed");
			closed();
		});
	}

	function tick():Bool {
		try {
			var data = socket.read();
			if (data != null) {
				if (data.length > 0)
					receive(data);
				return true;
			} else
				logger.debug('Connection closed by peer');
		} catch (e)
			logger.error('Failed to tick: $e');
		return false;
	}

	function toString() {
		return logger.name;
	}
}
#end
