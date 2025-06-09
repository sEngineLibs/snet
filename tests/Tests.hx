package;

import slog.Log;
import snet.ws.WebSocketClient;
import snet.ws.WebSocketServer;

class Tests {
	static function main() {
		Log.stamp = true;
		run();
	}

	static function run() {
		var ser = new WebSocketServer("ws://localhost:5050");
		ser.onData(d -> trace(d.toString()));

		new WebSocketClient("ws://localhost:5050");
	}
}
