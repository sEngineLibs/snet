package snet.http;

import haxe.io.Bytes;
import snet.http.Http;
import snet.internal.Client;

#if !macro
@:build(ssignals.Signals.build())
#end
class HttpClient extends Client {
	@:signal function response(response:HttpResponse);

	@async function connectClient():Void {}

	@async function closeClient():Void {}

	@async function receive(data:Bytes):Void {
		response(data.toString());
	}

	@async public function request(request:HttpRequest, ?timeout:Float = 10.0) {
		@await send(Bytes.ofString(request));
	}
}
