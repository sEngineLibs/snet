package;

import sasync.Async;
import snet.http.Http;

class Tests {
	static function main() {
		run();
	}

	@async static function run() {
		trace(@await Http.request("http://localhost:50"));
	}
}
