package snet.tcp;

import haxe.io.Bytes;

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
