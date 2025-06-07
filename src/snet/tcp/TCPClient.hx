package snet.tcp;

import haxe.io.Bytes;

class TCPClient extends snet.internal.Client {
	@:signal function message(data:Bytes);

	@async function receive(data:Bytes) {
		message(data);
	}

	@async function connectClient() {}

	@async function closeClient() {}
}
