package;

import snet.http.HttpServer;

class Tests {
	static function main() {
		run();
	}

	static function run() {
		var http = new HttpServer("http://localhost:80");
		http.onClientOpened(c -> c.onRequest(r -> {
			trace(r);
			var html = '<!DOCTYPE html><html><head><title>Hi</title></head><body><h1>Hello, world!</h1></body></html>';
			c.response({
				status: 200,
				headers: [
					CONTENT_TYPE => "text/html; charset=utf-8",
					CONTENT_LENGTH => Std.string(html.length)
				],
				data: html
			});
		}));

		if (Sys.stdin().readLine() == "close")
			http.close();
	}
}
