package;

import snet.Requests;

class Tests {
	static function main() {
		trace(@await Requests.get("http://example.com/"));
	}
}
