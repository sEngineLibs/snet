package snet.tcp;

import snet.internal.Server;

class TCPServer extends Server<TCPClient> {
	@async function handleClient(socket):Bool {
		return true;
	}
}
