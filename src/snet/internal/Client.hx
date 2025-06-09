package snet.internal;

import haxe.io.Bytes;
import snet.internal.Socket;

class ClientError extends haxe.Exception {}

#if !macro
@:build(ssignals.Signals.build())
#end
class Client {
	static function parseURI(uri:String) {
		var regex = new EReg("^(?:([a-z]+)://([^:/]+)(?::(\\d+))?|([^:/]+)(?::(\\d+))?)$", "i");

		if (!regex.match(uri))
			return null;

		var proto = regex.matched(1) != null ? regex.matched(1).toLowerCase() : null;
		var host = regex.matched(2) != null ? regex.matched(2) : regex.matched(4);
		var portStr = regex.matched(3) != null ? regex.matched(3) : regex.matched(5);

		var isSecure = proto == "https" || proto == "wss";
		if (proto == null)
			proto = "http";

		var port = portStr != null ? Std.parseInt(portStr) : isSecure ? 443 : 80;

		return {
			host: host,
			port: port,
			isSecure: isSecure,
			proto: proto
		}
	}

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

	public function new(uri:String, connect:Bool = true, ?cert:Certificate):Void {
		var info = parseURI(uri);
		if (info == null)
			throw new ClientError('Invalid URI: $uri');

		if (info.isSecure)
			cert = cert ?? {
				cert: SecureCertificate.loadDefaults(),
				key: null,
				verify: false
			}
		else
			cert = null;

		certificate = cert;
		remote = new HostInfo(info.host, info.port);

		if (connect)
			this.connect();
	}

	@async function connectClient():Void {}

	@async function closeClient():Void {}

	@async public function connect():Void {
		if (!isClosed)
			throw new ClientError("Client is already connected");
		var secureSocket:SecureSocket = null;
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
			if (isSecure && secureSocket != null)
				secureSocket.handshake();
			local = new HostInfo(socket.host.host.toString(), socket.host.port);
			isClosed = false;
			@await connectClient();
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
				} else
					log("Connection closed by peer");
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
