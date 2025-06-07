package snet.tcp;

import snet.internal.Server;

class TCPServer extends Server<TCPClient> {
	@async function receive(data):Void {}

	@async function connectClient():Void {}

	@async function handleClient(socket):Bool {
		return true;
	}
}
