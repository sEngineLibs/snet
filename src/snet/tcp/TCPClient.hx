package snet.tcp;

import haxe.io.Bytes;

#if !macro
@:build(ssignals.Signals.build())
#end
class TCPClient extends snet.internal.Client {
	@:signal function message(data:Bytes);

	@async function receive(data:Bytes) {
		trace(data.toString());
		message(data);
	}

	@async function connectClient() {}

	@async function closeClient() {}
}
