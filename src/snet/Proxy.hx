package snet;

@:forward()
abstract Proxy(ProxyData) from ProxyData to ProxyData {
	@:from
	public static function fromString(value:String):Proxy {
		var host = null;
		var port = 0;
		var auth = {
			user: null,
			pass: null
		}

		var parts1 = value.split("://");
		var parts2 = parts1.length > 1 ? parts1[1] : parts1[0];
		var authAndHost = parts2.split("@");

		if (authAndHost.length > 1) {
			var authParts = authAndHost[0].split(":");
			auth.user = authParts[0];
			auth.pass = authParts[1];
			parts2 = authAndHost[1];
		} else
			parts2 = authAndHost[0];

		var hostParts = parts2.split(":");
		host = hostParts[0];
		port = Std.parseInt(hostParts[1]);

		return new Proxy(host, port, auth);
	}

	public function new(host:String, port:Int, auth:{
		user:String,
		pass:String
	}) {
		this = {
			host: host,
			port: port,
			auth: auth
		}
	}

	@:to
	public inline function toString():String {
		var str = "";
		if (this.auth != null && this.auth.user != null && this.auth.pass != null)
			str += this.auth.user + ":" + this.auth.pass + "@";
		str += this.host + ":" + this.port;
		return str;
	}
}

private typedef ProxyData = {
	host:String,
	port:Int,
	auth:{
		user:String, pass:String
	}
};
