package;

import snet.ws.WebSocketClient;
import snet.ws.WebSocketHost;
import haxe.io.Bytes;

class Tests {
	static function main() {
		var server = new WebSocketHost("localhost", 8080, false);
		server.onClientOpen = (c) -> trace("client connected");
		server.onClientMessage = (c, m) -> trace(m.toString());

		server.start();

		var client = new WebSocketClient("localhost", 8080);
		client.onopen = () -> {
			trace("sent hello");
			client.send(Bytes.ofString("hello"));
		}

		while (true) {}
	}
}
