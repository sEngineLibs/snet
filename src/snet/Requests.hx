package snet;

import sys.net.Socket;
import haxe.Http;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

typedef Request = {
	?headers:Map<String, String>,
	?data:String,
	?bytes:Bytes,
	?params:Map<String, String>
};

typedef Response = {
	var status:Int;
	var headers:Map<String, String>;
	var data:String;
	var error:String;
};

typedef Proxy = {
	host:String,
	port:Int,
	auth:{
		user:String, pass:String
	}
};

class Requests {
	public static var proxy(get, set):Proxy;

	public static function get(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "GET", timeout);

	public static function post(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "POST", timeout);

	public static function put(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "PUT", timeout);

	public static function delete(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "DELETE", timeout);

	@async public static function request(url:String, ?sock:Socket, ?req:Request, ?method:String, timeout:Float = 10, noShutdown:Bool = false):Response {
		var http = new Http(url);
		http.cnxTimeout = timeout;
		http.noShutdown = noShutdown;

		if (req != null) {
			if (req.headers != null)
				for (k in req.headers.keys())
					http.setHeader(k, req.headers.get(k));
			if (req.params != null)
				for (k in req.params.keys())
					http.setParameter(k, req.params.get(k));
			if (req.data != null) {
				method = "POST";
				http.setPostData(req.data);
			}
			if (req.bytes != null) {
				method = "POST";
				http.setPostBytes(req.bytes);
			}
		}
		var post = method == "POST";

		var resp:Response = {
			status: 0,
			headers: new Map(),
			data: null,
			error: null
		};

		var output = new BytesOutput();
		http.onError = e -> resp.error = e;
		http.onStatus = code -> resp.status = code;
		http.customRequest(post, output, sock, method);

		resp.headers = http.responseHeaders;
		if (resp.error == null)
			resp.data = output.getBytes().toString();

		return resp;
	}

	static function get_proxy():Proxy {
		return Http.PROXY;
	}

	static function set_proxy(value:Proxy):Proxy {
		Http.PROXY = value;
		return proxy;
	}
}
