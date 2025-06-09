package snet.internal;

import haxe.io.Bytes;
import sys.thread.Thread;
import snet.Net;
import snet.internal.Socket;

class ClientError extends haxe.Exception {}

#if !macro
@:build(ssignals.Signals.build())
@:autoBuild(ssignals.Signals.build())
#end
class Client {
	var socket:Socket;

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

	@:signal function data(data:Bytes);

	public function new(uri:URI, connect:Bool = true, process:Bool = true, ?certificate:Certificate):Void {
		var info = uri.parse();
		if (info == null)
			throw new ClientError('Invalid URI: $uri');

		isSecure = info.isSecure;
		this.certificate = certificate;
		remote = new HostInfo(info.host, info.port);

		if (connect)
			this.connect(process);
	}

	function connectClient():Void {}

	function closeClient():Void {}

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
			socket.connect(new sys.net.Host(remote.host), remote.port);
			if (certificate?.verify && secureSocket != null)
				secureSocket.handshake();
			local = new HostInfo(socket.host.host.toString(), socket.host.port);
			isClosed = false;
			connectClient();
			log("Connected");
			opened();
			if (process)
				this.process();
		} catch (e) {
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
				log('Sent ${data.length} bytes of data');
			else
				throw new ClientError("Client is not available for writing");
		} catch (e) {
			log('Failed to send data: $e');
			throw e;
		}
	}

	function process():Void {
		Thread.create(() -> {
			while (!isClosed)
				if (!tick())
					break;
			isClosed = true;
			closeClient();
			socket.close();
			log("Closed");
			closed();
		});
	}

	function tick():Bool {
		if (!isClosed) {
			try {
				var data = socket.recv();
				if (data != null) {
					if (data.length > 0) {
						log('Received ${data.length} bytes of data');
						this.data(data);
					}
					return true;
				}
			} catch (e)
				log('Failed to tick: $e');
		}
		return false;
	}

	function log(msg:String) {
		slog.Log.debug('CLIENT [$local - $remote] | $msg');
	}
}
