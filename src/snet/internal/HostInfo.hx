package snet.internal;

@:forward(host, port)
abstract HostInfo(HostInfoData) from HostInfoData to HostInfoData {
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
