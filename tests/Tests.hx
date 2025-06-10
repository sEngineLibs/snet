package;

import slog.Log;
import sys.thread.Thread;
import snet.ws.WebSocketServer;
import snet.ws.WebSocketClient;

class Tests {
	static function main() {
		run();
	}

	static function run() {
		Thread.current().events.promise();

		var ser = new WebSocketServer("ws://localhost:8080");
		ser.onClientOpened(c -> {
			c.send("Hi from server!");
			c.onMessage(m -> switch m {
				case Text(text):
					Log.debug(text);
				default:
			});
		});
		ser.onClientClosed(c -> ser.close());
		ser.onClosed(() -> Thread.current().events.runPromised(() -> {}));

		var cli = new WebSocketClient("ws://localhost:8080");
		cli.onOpened(() -> {
			cli.send("Hi from client!");
			cli.close();
		});
	}
}
