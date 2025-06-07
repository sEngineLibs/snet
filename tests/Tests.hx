package;

import snet.http.HttpServer;

class Tests {
	static function main() {
		run();
	}

	@async static function run() {
		var server = new HttpServer("localhost", 8080, 10, false, false);
		server.onError(e -> trace(e));
		server.onOpened(() -> trace("server opened"));
		server.onClientOpened(c -> c.onMessage(m -> trace(m)));
		server.onRequest(req -> {
			var html = '<!DOCTYPE html><html><head><title>Hi</title></head><body><h1>Hello, world!</h1></body></html>';
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
