package snet.http;

#if sys
import sys.net.Socket;
#end
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
	var ?data:String;
	var ?error:String;
};

class Http {
	public static var proxy(get, set):Proxy;

	public static function get(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "GET", timeout);

	public static function post(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "POST", timeout);

	public static function put(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "PUT", timeout);

	public static function delete(url:String, ?req:Request, timeout:Float = 10)
		return request(url, req, "DELETE", timeout);

	#if sys
	public static function request(url:String, ?req:Request, ?method:String, timeout:Float = 10, ?sock:Socket, noShutdown:Bool = false)
	#else
	public static function request(url:String, ?req:Request, ?method:String, timeout:Float = 10)
	#end
	{
		var http = new haxe.Http(url);

		http.cnxTimeout = timeout;
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
			headers: new Map()
		};

		http.onError = e -> resp.error = e;
		http.onStatus = code -> resp.status = code;
		#if sys
		var output = new BytesOutput();

		http.noShutdown = noShutdown;
		http.customRequest(post, output, sock, method);
		if (resp.error == null)
			resp.data = output.getBytes().toString();
		#else
		Http.request(post);
		#end
		if (http.responseHeaders != null)
			resp.headers = http.responseHeaders;
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
