package snet.internal;

#if (nodejs || sys)
import sys.net.Host;
import haxe.Exception;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import snet.Net;

// imports
typedef SecureKey = sys.ssl.Key;
typedef SecureCertificate = sys.ssl.Certificate;

typedef SysSocket = // native socket
	// #if eval snet.internal.eval.Socket // eval
	#if nodejs snet.internal.node.Socket // nodejs
	#elseif php php.net.Socket // php
	#else sys.net.Socket // other sys platforms
	#end;
typedef SysSecureSocket = // native secure socket
	#if python python.net.SslSocket // python
	#elseif php php.net.SslSocket // php
	#else sys.ssl.Socket // other sys platforms
	#end;

// types
typedef Certificate = {
	?host:String,
	cert:SecureCertificate,
	key:SecureKey,
	verify:Bool
}

typedef ConnectionInfo = {
	ip:Int,
	info:HostInfo
}

class SocketError extends Exception {}

@:forward()
@:forward.new
abstract Socket(ASocket<SysSocket>) from SysSocket to SysSocket {
	public static function select(read:Array<Socket>, write:Array<Socket>, others:Array<Socket>, ?timeout:Float) {
		return SysSocket.select(read, write, others, timeout);
	}

	public function accept():Socket {
		return this.accept();
	}
}

// @:forward()
// @:forward.new
// abstract SecureSocket(ASocket<SysSecureSocket>) from SysSecureSocket to SysSecureSocket {
// 	public function new(?certificate:Certificate, isClient:Bool = true) {
// 		this = new SysSecureSocket();
// 		if (certificate != null) {
// 			this.setCA(certificate.cert);
// 			this.verifyCert = certificate.verify;
// 			if (isClient && certificate.verify)
// 				this.setCertificate(certificate.cert, certificate.key);
// 			else {
// 				this.setCertificate(certificate.cert, certificate.key);
// 				this.setHostname(certificate.host);
// 			}
// 		}
// 	}
// 	@:to
// 	function toSocket():Socket {
// 		return (this : SysSocket);
// 	}
// 	public function accept():SecureSocket {
// 		return cast(this.accept(), SecureSocket);
// 	}
// }

@:forward()
@:forward.new
private abstract ASocket<T:SysSocket>(T) from T to T {
	/**
		Return the information about our side of a connected socket.
	**/
	public var host(get, never):ConnectionInfo;

	/**
		Return the information about the other side of a connected socket.
	**/
	public var peer(get, never):ConnectionInfo;

	/**
		Bind the socket to the given host/port so it can afterwards listen for connections there.
	**/
	overload extern public inline function bind(host:HostInfo) {
		bind(host.host, host.port);
	}

	/**
		Bind the socket to the given host/port so it can afterwards listen for connections there.
	**/
	overload extern public inline function bind(host:String, port:Int) {
		this.bind(new Host(host), port);
	}

	/**
		Connect to the given server host/port. Throw an exception in case we couldn't successfully connect.
	**/
	overload extern public inline function connect(host:HostInfo) {
		connect(host.host, host.port);
	}

	/**
		Connect to the given server host/port. Throw an exception in case we couldn't successfully connect.
	**/
	overload extern public inline function connect(host:String, port:Int) {
		this.connect(new Host(host), port);
	}

	/**
		Read the whole data available on the socket.

		*Note*: this is **not** meant to be used together with `setBlocking(false)`,
		as it will always throw `haxe.io.Error.Blocked`. `input` methods should be used directly instead.
	**/
	public function read(bufSize:Int = 4096, ?timeout:Float) {
		if (Socket.select([this], [], [], timeout).read.length == 0)
			return Bytes.alloc(0);
		var data = new BytesBuffer();
		final buf = Bytes.alloc(bufSize);

		try {
			while (true) {
				var len = this.input.readBytes(buf, 0, buf.length);
				if (len <= 0)
					return null;
				data.addBytes(buf, 0, len);
				if (len < buf.length)
					break;
			}
		} catch (e)
			if (e.toString().toLowerCase().indexOf("eof") != -1)
				return null;
			else
				throw e;

		return data.getBytes();
	}

	function get_host() {
		return getConnectionInfo(this.host());
	}

	function get_peer() {
		return getConnectionInfo(this.peer());
	}

	function getConnectionInfo(info:{host:Host, port:Int}) {
		return {
			ip: info.host.ip,
			info: {
				host: info.host.toString(),
				port: info.port
			}
		}
	}
}
#end
