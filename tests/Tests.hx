package;

import snet.http.Http;
import snet.http.HttpServer;

class Tests {
	static function main() {
		var echo = new HttpServer("http://localhost:80");
		echo.onClientOpened(c -> c.onRequest(r -> c.response({
			data: r.data
		})));

		trace(Http.request("http://localhost:80"));
	}
}
