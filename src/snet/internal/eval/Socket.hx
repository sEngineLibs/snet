package snet.internal.eval;

#if (eval && sys)
import sys.net.Host;
import sys.thread.Lock;
import sys.thread.Thread;
import sys.thread.EventLoop;
import haxe.io.Eof;
import haxe.io.Bytes;
import haxe.io.Input;
import haxe.io.Output;
import eval.luv.Tcp;
import eval.luv.Result;
import eval.luv.Buffer;
import eval.luv.SockAddr;

class Socket {
	public static function select(read:Array<Socket>, write:Array<Socket>, others:Array<Socket>,
			?timeout:Float):{read:Array<Socket>, write:Array<Socket>, others:Array<Socket>} {
		read = read.copy();
		write = write.copy();
		timeout = timeout ?? 0.0;
		var _read = [];
		var _write = [];
		var _start = Sys.time();
		function append() {
			for (s in read)
				if (s.native.isReadable()) {
					_read.push(s);
					read.remove(s);
				}
			for (s in write)
				if (s.native.isWritable()) {
					_write.push(s);
					write.remove(s);
				}
			if (read.length == 0 && write.length == 0)
				return;
			else if (Sys.time() - _start >= timeout)
				return;
			else
				append();
		}
		append();
		return {
			read: _read,
			write: _write,
			others: others
		}
	}

	static inline function _try<T>(r:Result<T>):T {
		if (r != null)
			return switch r {
				case Ok(value):
					value;
				case Error(e):
					throw e.toString();
			}
		return null;
	}

	static var loop:EventLoop;

	var native:Tcp;
	var timeout:Float;
	var acceptLock:Lock = new Lock();

	public var input(default, null):Input;
	public var output(default, null):Output;

	public function new() {
		if (loop == null) {
			var lock = new Lock();
			Thread.createWithEventLoop(() -> {
				loop = Thread.current().events;
				loop.promise();
				lock.release();
			});
			lock.wait();
		}
		native = _try(Tcp.init(loop));
		input = new Input(this);
		output = new Output(this);
	}

	public function host():{host:Host, port:Int} {
		var _peer = _try(native.getSockName());
		return {
			host: new Host(_peer.toString()),
			port: _peer.port
		}
	}

	public function peer():{host:Host, port:Int} {
		var _peer = _try(native.getPeerName());
		return {
			host: new Host(_peer.toString()),
			port: _peer.port
		}
	}

	public function connect(host:sys.net.Host, port:Int) {
		var lock = new Lock();
		var err = null;
		native.connect(_try(SockAddr.ipv4(host.toString(), port)), r -> {
			_try(r);
			lock.release();
		});
		lock.wait();
		if (err != null)
			throw err;
		input.startRead();
	}

	public function close() {
		var lock = new Lock();
		native.close(lock.release);
		lock.wait();
	}

	public function bind(host:sys.net.Host, port:Int) {
		_try(native.bind(_try(SockAddr.ipv4(host.toString(), port))));
	}

	public function listen(connections:Int) {
		native.listen(r -> {
			_try(r);
			acceptLock.release();
		}, connections);
	}

	public function accept():Socket {
		acceptLock.wait();
		var conn = new Socket();
		_try(native.accept(conn.native));
		conn.input.startRead();
		return conn;
	}

	public function shutdown(read:Bool, write:Bool) {
		if (read)
			_try(native.readStop());
		if (write) {
			var lock = new Lock();
			native.shutdown(r -> {
				lock.release();
				_try(r);
			});
			lock.wait();
		}
	}

	public function setFastSend(b:Bool) {
		_try(native.noDelay(b));
	}

	public function setBlocking(b:Bool) {
		_try(native.setBlocking(b));
	}
}

@:allow(snet.internal.eval.Socket)
@:access(snet.internal.eval.Socket)
class Input extends haxe.io.Input {
	var lock:Lock = new Lock();
	var socket:Socket;
	var buffers:Array<Buffer> = [];

	public function new(socket:Socket) {
		this.socket = socket;
	}

	/**
		Read and return one byte.
	**/
	override function readByte():Int {
		if (buffers.length == 0)
			lock.wait();
		var res = buffers[0].get(0);
		buffers = Buffer.drop(buffers, 1);
		return res;
	}

	/**
		Read `len` bytes and write them into `s` to the position specified by `pos`.

		Returns the actual length of read data that can be smaller than `len`.

		See `readFullBytes` that tries to read the exact amount of specified bytes.
	**/
	override function readBytes(s:Bytes, pos:Int, len:Int):Int {
		if (pos < 0 || len < 0 || pos + len > s.length)
			throw haxe.io.Error.OutsideBounds;
		if (buffers.length == 0)
			lock.wait();
		var l = 0;
		var err = null;
		for (b in buffers) {
			var bs = b.size();
			if (bs > 0) {
				var rl = bs < len ? bs : len;
				b.sub(0, rl).blitToBytes(s, pos);
				l += rl;
				pos += rl;
				len -= rl;
			} else {
				err = Eof;
				break;
			}
		}
		buffers = Buffer.drop(buffers, l);
		if (err != null)
			throw err;
		return l;
	}

	/**
		Close the input source.

		Behaviour while reading after calling this method is unspecified.
	**/
	override function close() {
		Socket._try(socket.native.readStop());
	}

	function startRead() {
		socket.native.readStart(r -> {
			switch r {
				case Ok(value):
					buffers.push(value);
					lock.release();
				case Error(e):
					close();
			}
		});
	}
}

@:allow(snet.internal.eval.Socket)
@:access(snet.internal.eval.Socket)
class Output extends haxe.io.Output {
	var socket:Socket;
	var buffers:Array<Buffer> = [];

	public function new(socket:Socket) {
		this.socket = socket;
	}

	/**
		Write one byte.
	**/
	override function writeByte(c:Int):Void {
		var buffer = Buffer.create(1);
		buffer.fill(c);
		buffers.push(buffer);
	}

	/**
		Write `len` bytes from `s` starting by position specified by `pos`.

		Returns the actual length of written data that can differ from `len`.

		See `writeFullBytes` that tries to write the exact amount of specified bytes.
	**/
	override function writeBytes(s:Bytes, pos:Int, len:Int):Int {
		writeFullBytes(s, pos, len);
		return len;
	}

	/**
		Write all bytes stored in `s`.
	**/
	override function write(s:Bytes):Void {
		buffers.push(Buffer.fromBytes(s));
	}

	/**
		Write `len` bytes from `s` starting by position specified by `pos`.

		Unlike `writeBytes`, this method tries to write the exact `len` amount of bytes.
	**/
	override function writeFullBytes(s:Bytes, pos:Int, len:Int) {
		write(s.sub(pos, len));
	}

	/**
		Flush any buffered data.
	**/
	override function flush() {
		Socket._try(socket.native.tryWrite(buffers));
	}
}
#end
