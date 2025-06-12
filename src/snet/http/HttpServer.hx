package snet.http;

#if (nodejs || sys)
import haxe.io.Bytes;
import snet.http.Http;
import snet.internal.Client;

typedef HttpServer = snet.internal.Server<HttpClient>;

#if !macro
@:build(ssignals.Signals.build())
#end
class HttpClient extends snet.internal.Client {
	@:signal function request(request:HttpRequest);

	override function receive(data:Bytes) {
		request(data.toString());
	}

	public function response(response:HttpResponse) {
		trace(response);
		send(Bytes.ofString(response));
	}
}
#end
