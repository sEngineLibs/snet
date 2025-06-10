package snet.internal;

import haxe.io.Bytes;
import slog.Log;
import snet.Net;
import snet.internal.Socket;

class ClientError extends haxe.Exception {}

#if !macro
@:build(ssignals.Signals.build())
#end
abstract class Client {
	var socket:Socket;
	var logger:Logger = new Logger("CLIENT");

	public var isClosed(default, null):Bool = true;
	public var isSecure(default, null):Bool;
	public var certificate(default, null):Certificate;

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

	public function new(uri:URI, connect:Bool = true, process:Bool = true, ?certificate:Certificate):Void {
		if (uri == null)
			throw new ClientError('Invalid URI');

		isSecure = uri.isSecure;
		this.certificate = certificate;
		remote = uri.host;

		if (connect)
			this.connect(process);
	}

	abstract function receive(data:Bytes):Void;

	abstract function connectClient():Void;

	abstract function closeClient():Void;

	public function connect(process:Bool = true):Void {
		if (!isClosed)
			throw new ClientError("Client is already connected");
		var secureSocket:SecureSocket = null;
		if (isSecure) {
			secureSocket = new SecureSocket(certificate);
			socket = secureSocket;
		} else
			socket = new Socket();
		try {
			socket.connect(remote);
			if (certificate?.verify && secureSocket != null)
				secureSocket.handshake();
			local = socket.host.info;
			logger.name = 'CLIENT $local - $remote';
			isClosed = false;
			connectClient();
			logger.debug("Connected");
			opened();
			if (process)
				this.process();
		} catch (e) {
			logger.error('Failed to connect: $e');
			socket.close();
			throw e;
		}
	}

	public function close():Void {
		if (isClosed)
			throw new ClientError("Client is not connected");
		isClosed = true;
	}

	public function send(data:Bytes):Void {
		if (isClosed)
			throw new ClientError("Client is not connected");
		try {
			if (socket.send(data))
				logger.info('Sent ${data.length} bytes of data');
			else
				throw new ClientError("Client is not available for writing");
		} catch (e) {
			logger.error('Failed to send data: $e');
			throw e;
		}
	}

	function process():Void {
		#if target.threaded
		sys.thread.Thread.create(() -> {
		#end
			while (!isClosed)
				if (!tick())
					break;
			isClosed = true;
			closeClient();
			socket.close();
			logger.debug("Closed");
			closed();
		#if target.threaded
		});
		#end
	}

	function tick():Bool {
		try {
			var data = socket.recv();
			if (data != null) {
				if (data.length > 0) {
					logger.info('Received ${data.length} bytes of data');
					receive(data);
				}
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
