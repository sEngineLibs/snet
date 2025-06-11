package snet;

class NetError extends haxe.Exception {}

@:forward()
abstract URI(URIData) from URIData to URIData {
	@:from
	public static function fromString(value:String):URI {
		var reg = new EReg("^(?:(?:([a-z][a-z0-9+\\-.]*)):)?(?:\\/\\/)?(?:(?:([^:@]+)(?::([^@]*))?@)?([^\\/?#]*))?(\\/[^?#]*)?(?:\\?([^#]*))?(?:#(.*))?$", "i");
		if (value == null || !reg.match(value))
			return null;

		var proto = reg.matched(1);
		var isSecure = proto != null && (proto == "https" || proto == "wss");

		var rawHost = reg.matched(4);

		return {
			proto: proto,
			isSecure: isSecure,
			host: rawHost != null ? HostInfo.fromString(rawHost) : null,
			user: reg.matched(2),
			pass: reg.matched(3),
			path: reg.matched(5) ?? "/",
			query: reg.matched(6),
			fragment: reg.matched(7)
		};
	}

	@:to
	public function toString():String {
		var str = "";

		if (this.proto != null)
			str += '${this.proto}://';

		if (this.user != null) {
			str += this.user;
			if (this.pass != null)
				str += ':${this.pass}';
			str += '@';
		}

		str += this.host;
		str += this.path ?? "";
		str += this.query ?? "";
		str += this.fragment ?? "";

		return str;
	}
}

@:forward()
abstract Proxy(ProxyData) from ProxyData to ProxyData {
	@:from
	public static function fromString(value:String):Proxy {
		var reg = new EReg("^(?:(?P<user>[^:@]+)(?::(?P<pass>[^@]*))?@)?([^/?#]+)$", "i");
		if (value == null || !reg.match(value))
			return null;

		return {
			host: reg.matched(3),
			auth: reg.matched(1) != null ? {
				user: reg.matched(1),
				pass: reg.matched(2)
			} : null
		};
	}

	@:to
	public function toString():String {
		var str = "";

		if (this.auth != null && this.auth.user != null) {
			str += this.auth.user;
			if (this.auth.pass != null)
				str += ':${this.auth.pass}';
			str += '@';
		}

		str += this.host;
		return str;
	}
}

@:forward()
abstract HostInfo(HostInfoData) from HostInfoData to HostInfoData {
	@:from
	public static function fromString(value:String):HostInfo {
		var regex = ~/^([^:]+)(?::(\d+))?$/;
		if (value == null || !regex.match(value))
			return null;
		return new HostInfo(regex.matched(1), regex.matched(2) != null ? Std.parseInt(regex.matched(2)) : 80);
	}

	public function new(host:String, port:Int) {
		this = {
			host: host,
			port: port
		}
	}

	@:to
	public inline function toString():String {
		return '${this.host}:${this.port}';
	}
}

private typedef HostInfoData = {
	host:String,
	port:Int
}

private typedef URIData = {
	host:HostInfo,
	isSecure:Bool,
	?proto:String,
	?user:String,
	?pass:String,
	?path:String,
	?query:String,
	?fragment:String
};

private typedef ProxyData = {
	host:HostInfo,
	?auth:{
		user:String,
		?pass:String
	}
};
