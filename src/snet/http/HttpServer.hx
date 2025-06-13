package snet.http;

#if (nodejs || sys)
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import haxe.io.Bytes;
import snet.Net;
import snet.internal.Socket;
import snet.internal.Client;

using StringTools;

@:nullSafety
typedef ServerConfig = {
	location:String,
	statics:Array<String>
}

abstract class HttpServer extends snet.internal.Server<Client> {
	public var config:ServerConfig;

	public function new(uri:URI, limit:Int = 10, open:Bool = true, ?cert:Certificate, ?config:ServerConfig) {
		super(uri, limit, open, cert);
		this.config = config;

		onClientOpened(client -> {
			var callback = (data:Bytes) -> {
				var resp = processRawRequest(data);
				logger.info('-> ${resp.status} ${resp.statusText}');
				client.send(resp);
			};
			client.onData(callback);
			client.onClosed(() -> client.offData(callback));
		});
	}

	abstract function processRequest(req:Request):Response;

	function processRawRequest(data:Bytes):Response {
		var req:Request = data;
		if (req != null) {
			logger.debug('<- ${req.method} ${req.path}');
			switch req.method {
				case Get:
					switch req.path {
						case "/":
							return loadStatic("/index.html");
						case var s if (config?.statics.contains(s)):
							return loadStatic(s);
						default:
							return processRequest(req);
					}
				default:
					return processRequest(req);
			}
		}
		return {
			status: BadRequest,
			statusText: "Bad Request"
		}
	}

	function loadStatic(path:String):Response {
		path = config.location + path;
		if (FileSystem.exists(path)) {
			try {
				var bytes = File.getBytes(path);
				var ext = Path.extension(path);
				switch ext {
					case "js":
						return {
							data: bytes.toString(),
							headers: [CONTENT_TYPE => "application/javascript; charset=utf-8"]
						}
					case "css":
						return {
							data: bytes.toString(),
							headers: [CONTENT_TYPE => "text/css; charset=utf-8"]
						}
					case "html":
						return {
							data: bytes.toString(),
							headers: [CONTENT_TYPE => "text/html; charset=utf-8"]
						}
					case "json":
						return {
							data: bytes.toString(),
							headers: [CONTENT_TYPE => "application/json"]
						}
					case "png", "gif", "jpg", "jpeg":
						return {
							bytes: bytes,
							headers: [CONTENT_TYPE => 'image/$ext']
						}
					default:
						return {
							bytes: bytes,
							headers: [CONTENT_TYPE => "application/octet-stream"]
						}
				}
			} catch (e)
				return {
					status: InternalServerError,
					statusText: "Internal Server Error"
				}
		} else
			return {
				status: NotFound,
				statusText: "Not Found"
			}
	}
}
#end
