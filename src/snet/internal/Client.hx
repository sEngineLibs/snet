package snet.internal;

import haxe.Exception;
import haxe.io.Bytes;
import snet.internal.Socket;

class ClientError extends Exception {}

#if !macro
@:build(ssignals.Signals.build())
#end
class Client {
	var socket:Socket;

	public var certificate(default, null):Certificate;
	public var isClosed(default, null):Bool = true;

	/**
		Our side of a connected socket.
	**/
	public var local(default, null):HostInfo;

	/**
		The other side of a connected socket.
	**/
	public var remote(default, null):HostInfo;

	public var isSecure(get, never):Bool;

	@:signal function opened();

	@:signal function closed();

	@:signal function data(data:Bytes);

	public function new(host:String, port:Int, connect:Bool = true, ?cert:Certificate):Void {
		this.certificate = cert;
		remote = new HostInfo(host, port);
		if (connect)
			this.connect();
	}

	@async function connectClient():Void {}

	@async function closeClient():Void {}

	@async public function connect():Void {
		if (!isClosed)
			throw new ClientError("Client is already connected");
		var secureSocket:SecureSocket;
		if (isSecure) {
			secureSocket = new SecureSocket();
			secureSocket.setCA(certificate.cert);
			if (certificate.verify)
				secureSocket.setCertificate(certificate.cert, certificate.key);
			secureSocket.verifyCert = certificate.verify;
			socket = secureSocket;
		} else
			socket = new Socket();
		try {
			@await socket.connect(new sys.net.Host(remote.host), remote.port);
			if (isSecure)
				secureSocket.handshake();
			local = new HostInfo(socket.host.host.toString(), socket.host.port);
			@await connectClient();
			isClosed = false;
			log("Connected");
			opened();
			process();
		} catch (e) {
			@await socket.close();
			throw e;
		}
	}

	@async public function close():Void {
		if (isClosed)
			throw new ClientError("Client is not connected");
		isClosed = true;
	}

	@async public function send(data:Bytes):Void {
		if (isClosed)
			throw new ClientError("Client is not connected");
		try {
			if ((@await Socket.select([], [socket], [])).write.length > 0) {
				log('Sending ${data.length} bytes of data');
				socket.output.write(data);
				socket.output.flush();
			} else
				throw new ClientError("Client is not available for writing");
		} catch (e) {
			log('Failed to send data: $e');
			throw e;
		}
	}

	@async function process():Void {
		if (@await tick())
			@await process();
		else {
			isClosed = true;
			@await closeClient();
			@await socket.close();
			log("Closed");
			closed();
		}
	}

	@async function tick():Bool {
		if (!isClosed) {
			try {
				var data = @await socket.receive();
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

	function get_isSecure():Bool {
		return certificate != null;
	}
}
