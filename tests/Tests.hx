package;

import haxe.io.Bytes;
import snet.tcp.TCPClient;
import snet.tcp.TCPServer;

class Tests {
	static function main() {
		run();
	}

	@async static function run() {
		var server = new TCPServer("localhost", 5050, 10, false, false);
		server.onError(e -> trace(e));
		server.onOpened(() -> trace("server opened"));
		server.onClientOpened(c -> c.onMessage(m -> trace(m.toString())));
		server.onClientClosed(c -> {
			c.message.clear();
			trace("client disconnected");
		});

		@await server.open();

		var client = new TCPClient("localhost", 5050);
		client.onError(e -> trace(e));
		client.onOpened(() -> {
			client.send(Bytes.ofString('hello'));
		});

		@await client.send(Bytes.ofString('bye'));
		@await client.close();
	}
}
