package;

import sasync.Async;
import sys.thread.Thread;
import snet.ws.WebSocketClient;
import snet.ws.WebSocketServer;

class Tests {
	static function main() {
		Thread.current().events.promise();
		run();
	}

	static function run() {
		var serv = new WebSocketServer("ws://localhost:8080");
		serv.onClientOpened(c -> c.onText(t -> trace(t)));

		var cli = new WebSocketClient("ws://localhost:8080");
		cli.onOpened(() -> {
			cli.send('Message 0');
			Async.sleep(1.0).handle(_ -> cli.close());
		});
	}
}
