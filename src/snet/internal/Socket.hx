package snet.internal;

#if sys
import sys.net.Host;
#end
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import sasync.Future;

// imports
typedef SysSocket = #if nodejs js.node.net.Socket #elseif php php.net.Socket #else sys.net.Socket #end;
typedef SysSecureSocket = #if java java.net.SslSocket #elseif python python.net.SslSocket #elseif php php.net.SslSocket #else sys.ssl.Socket #end;
typedef SecureKey = sys.ssl.Key;
typedef SecureCertificate = sys.ssl.Certificate;

// types
typedef Certificate = {
	?hostname:String,
	cert:SecureCertificate,
	key:SecureKey,
	verify:Bool
}

typedef Socket = ASocket<SysSocket>;

@:forward()
@:forward.new
abstract SecureSocket(ASocket<SysSecureSocket>) from SysSecureSocket to SysSecureSocket {
	@:to
	function toSocket():Socket {
		return (this : SysSocket);
	}

	/**
		Perform the SSL handshake.
	**/
	public function handshake() {
		return Background.run(() -> this.handshake());
	}
}

@:forward()
@:forward.new
private abstract ASocket<T:SysSocket>(T) from T to T {
	public static function select(read:Array<Socket>, write:Array<Socket>, others:Array<Socket>, ?timeout:Float) {
		return Background.run(() -> SysSocket.select(read, write, others, timeout));
	}

	public var host(get, never):{host:Host, port:Int};
	public var peer(get, never):{host:Host, port:Int};

	public function connect(host:Host, port:Int) {
		return Background.run(() -> this.connect(host, port));
	}

	public function close() {
		return Background.run(() -> this.close());
	}

	public function read() {
		return Background.run(() -> this.read());
	}

	public function write(content:String) {
		return Background.run(() -> this.write(content));
	}

	public function shutdown(read:Bool, write:Bool) {
		return Background.run(() -> this.shutdown(read, write));
	}

	public function bind(host:Host, port:Int) {
		return Background.run(() -> this.bind(host, port));
	}

	public function listen(connections:Int) {
		return Background.run(() -> this.listen(connections));
	}

	public function accept():Future<Socket> {
		return Background.run(() -> this.accept());
	}

	public function waitForRead() {
		return Background.run(() -> this.waitForRead());
	}

	@async public function receive(bufSize:Int = 4096, ?timeout:Float):Null<Bytes> {
		var list = Socket.select([this], [], [], timeout);
		var data = new BytesBuffer();
		if ((@await list).read.length == 0) {
			var buf = Bytes.alloc(bufSize);
			while (true) {
				var len = this.input.readBytes(buf, 0, bufSize);
				if (len > 0) {
					data.addBytes(buf, 0, len);
					if (len < bufSize)
						break;
				} else
					throw "Connection closed by peer";
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
