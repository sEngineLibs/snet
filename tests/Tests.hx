package;

import snet.http.HttpServer;

class Tests {
	static function main() {
		run();
	}

	@async static function run() {
		var server = new HttpServer("localhost", 8080, 10);
		server.onError(e -> trace(e));
		server.onOpened(() -> trace(server.local.toString()));
		server.onClientClosed(c -> trace(c.remote));
		server.onRequest(req -> {
			trace(req);
			var html = '<!DOCTYPE html><html><head><title>Hi</title></head><body><h1>Привет МАТВЕЙ!</h1></body></html>';
			server.response({
				status: 200,
				headers: [
					"Content-Type" => "text/html; charset=utf-8",
					"Content-Length" => Std.string(html.length)
				],
				data: html
			});
		});
		@await server.open();
	}
}
