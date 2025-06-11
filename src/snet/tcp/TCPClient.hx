package snet.tcp;

#if (nodejs || sys)
import haxe.io.Bytes;
import snet.internal.Socket;

#if !macro
@:build(ssignals.Signals.build())
#end
class TCPClient extends snet.internal.Client {
	@:signal function data(data:Bytes);

	function connectClient() {}

	function closeClient() {}

	function receive(data:Bytes) {
		this.data(data);
	}
}
#end
