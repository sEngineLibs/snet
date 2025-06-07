package snet.internal;

import sys.net.Host;
#if target.threaded
import sys.thread.Thread;
import sys.thread.EventLoop;
#end
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import sasync.Future;

typedef SysSocket = #if nodejs js.node.net.Socket #elseif php php.net.Socket #else sys.net.Socket #end;
typedef SysSecureSocket = #if java java.net.SslSocket #elseif python python.net.SslSocket #elseif php php.net.SslSocket #else sys.ssl.Socket #end;

@:forward(input, output, custom, setTimeout, setFastSend)
abstract Socket(SysSocket) from SysSocket to SysSocket {
	#if target.threaded
	static function runInBackground<T>(f:Void->T):Future<T> {
		static var pool:Array<EventLoop> = [];
		static var promised:Bool = false;

		if (!promised)
			Thread.current().events.promise();

		return new Future<T>((resolve, reject) -> {
			if (pool.length == 0) {
				var lock = new sys.thread.Lock();
				Thread.createWithEventLoop(() -> {
					var events = Thread.current().events;
					events.promise();
					pool.push(events);
					lock.release();
				});
				lock.wait();
			}
			var events = pool.pop();
			events.promise();
			events.runPromised(() -> {
				try {
					resolve(f());
				} catch (e)
					reject(e);
				if (pool.length == 0)
					pool.push(events);
				else
					events.runPromised(() -> {});
			});
		});
	}
	#else
	static function runInBackground<T>(f:Void->T):Future<T> {
		return new Future((resolve, _) -> resolve(f()));
	}
	#end

	public static function select(read:Array<Socket>, write:Array<Socket>, others:Array<Socket>, ?timeout:Float) {
		return runInBackground(() -> SysSocket.select(read, write, others, timeout));
	}

	public var host(get, never):{host:Host, port:Int};
	public var peer(get, never):{host:Host, port:Int};

	public function new(secure:Bool = false) {
		if (secure)
			this = new SysSecureSocket();
		else
			this = new SysSocket();
		this.setBlocking(true);
	}

	public function connect(host:Host, port:Int) {
		return runInBackground(() -> this.connect(host, port));
	}

	public function close() {
		return runInBackground(() -> this.close());
	}

	public function read() {
		return runInBackground(() -> this.read());
	}

	public function write(content:String) {
		return runInBackground(() -> this.write(content));
	}

	public function shutdown(read:Bool, write:Bool) {
		return runInBackground(() -> this.shutdown(read, write));
	}

	public function bind(host:Host, port:Int) {
		return runInBackground(() -> this.bind(host, port));
	}

	public function listen(connections:Int) {
		return runInBackground(() -> this.listen(connections));
	}

	public function accept():Future<Socket> {
		return runInBackground(() -> this.accept());
	}

	public function waitForRead() {
		return runInBackground(() -> this.waitForRead());
	}

	@async public function receive(bufSize:Int = 1024, timeout:Float = 0.1):Null<Bytes> {
		var data = new BytesBuffer();
		var list = @await Socket.select([this], [], [], timeout);
		if (list.read.length > 0) {
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
