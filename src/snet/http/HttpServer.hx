package snet.http;

import haxe.io.Bytes;
import snet.http.Requests;
import snet.internal.Socket;
import snet.internal.Server;
import snet.internal.Client;

#if !macro
@:build(ssignals.Signals.build())
#end
class HttpServer extends Server<Client> {
	@:signal function request(request:HttpRequest);

	public function new(host:String, port:Int, limit:Int = 10, open:Bool = true, ?cert:Certificate) {
		super(host, port, limit, open, cert);
	}

	public function response(response:HttpResponse) {
		send(Bytes.ofString(response));
	}

	@:slot(clientOpened)
	function trackClient(client:Client) {
		client.onData(data -> request(data.toString()));
	}
}
