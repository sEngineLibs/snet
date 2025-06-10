package;

import slog.Log;
import snet.ws.WebSocketServer;
import snet.ws.WebSocketClient;

class Tests {
	static function main() {
		run();
		haxe.Timer.delay(() -> Log.close(), 1000);
	}

	static function run() {
		var ser = new WebSocketServer("ws://localhost:8080");
		ser.onClientOpened(c -> c.onMessage(m -> switch m {
			case Text(text):
				Log.debug(text);
			default:
		}));

		var cli = new WebSocketClient("ws://localhost:8080");

		var input = Sys.stdin().readLine();
		while (input != "0") {
			cli.send(input);
			input = Sys.stdin().readLine();
		}
		ser.close();
	}
}
