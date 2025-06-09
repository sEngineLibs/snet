package;

import haxe.io.Bytes;
import slog.Log;
import snet.ws.WebSocketClient;
import snet.ws.WebSocketServer;

class Tests {
	static function main() {
		Log.stamp = true;
		run();
	}

	static function run() {
		var ser = new WebSocketServer("localhost:5050");
		ser.onData(d -> trace(d.toString()));
		ser.onClientOpened(c -> c.send(Bytes.ofString("hooray!")));

		// ser.onOpened(() -> {
		trace("connecting client");
		var cli = new WebSocketClient("localhost:5050");
		cli.onData(d -> trace(d.toString()));
		// });
	}
}
