package;

import slog.Log;
import snet.http.Requests;

class Tests {
	static function main() {
		Log.stamp = true;
		run();
	}

	@async static function run() {
		trace(@await Requests.request("http://example.com"));
	}
}
