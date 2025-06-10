package;

import haxe.Json;
import sys.thread.Thread;
import snet.http.Requests;
import snet.http.HttpServer;
import slog.Log;
import snet.ws.WebSocketServer;
import snet.ws.WebSocketClient;

class Tests {
	static function main() {
		run();
	}

	static function run() {
		var ser = new HttpServer("http://localhost:80");
		ser.onClientOpened(c -> c.onRequest(r -> {
			trace(r);
			c.response({
				headers: ["A" => "B"]
			});
		}));

		var resp = Requests.request("http://localhost:80", {
			data: Json.stringify({
				a: "b"
			})
		});
		trace(resp);

		Sys.getChar(true);
	}
}
