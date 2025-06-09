package snet.internal;

import sys.net.Host;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

// imports
typedef SecureKey = sys.ssl.Key;
typedef SecureCertificate = sys.ssl.Certificate;

typedef SysSocket = // native socket
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
	?hostname:String,
	cert:SecureCertificate,
	key:SecureKey,
	verify:Bool
}

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

@:forward()
@:forward.new
abstract SecureSocket(ASocket<SysSecureSocket>) from SysSecureSocket to SysSecureSocket {
	public function new(?certificate:Certificate, isClient:Bool = true) {
		this = new SysSecureSocket();
		if (certificate != null) {
			this.setCA(certificate.cert);
			this.verifyCert = certificate.verify;
			if (isClient && certificate.verify)
				this.setCertificate(certificate.cert, certificate.key);
			else {
				this.setCertificate(certificate.cert, certificate.key);
				this.setHostname(certificate.hostname);
			}
		}
	}

	@:to
	function toSocket():Socket {
		return (this : SysSocket);
	}

	public function accept():SecureSocket {
		return this.accept();
	}
}

@:forward()
@:forward.new
private abstract ASocket<T:SysSocket>(T) from T to T {
	public var host(get, never):{host:Host, port:Int};
	public var peer(get, never):{host:Host, port:Int};

	public function connect(host:String, port:Int) {
		this.connect(new Host(host), port);
	}

	public function send(data:Bytes, ?timeout:Float):Bool {
		if ((Socket.select([], [this], [], timeout)).write.length > 0) {
			this.output.write(data);
			this.output.flush();
			return true;
		}
		return false;
	}

	public function recv(bufSize:Int = 4096, ?timeout:Float):Null<Bytes> {
		var data = new BytesBuffer();
		if (Socket.select([this], [], [], timeout).read.length > 0) {
			var buf = Bytes.alloc(bufSize);
			while (true) {
				var len = this.input.readBytes(buf, 0, bufSize);
				if (len > 0) {
					data.addBytes(buf, 0, len);
					if (len < bufSize)
						break;
				} else
					return null;
			}
		}
		return data.getBytes();
	}

	function get_host() {
		return this.host();
	}

	function get_peer() {
		return this.peer();
	}
}
