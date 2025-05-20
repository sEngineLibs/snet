package snet;

#if sys
import haxe.Constraints;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;

abstract class NetClient<M> {
	public function new(host:String, port:Int, immediateConnect = true) {}


	abstract function receiveData(data:Bytes):Void;

}

@:generic
abstract class NetHost<M, C:Constructible<(String, Int, Bool) -> Void> & NetClient<M>> extends NetClient<M> {


	override function send(data:Bytes):Void {
		if (isClosed)
			onerror("Host is closed");
		else
			for (client in clients)
				client.send(data);
	}

	public function broadcast(data:Bytes, ?exclude:Array<HostInfo>):Void {
		function ex(info:HostInfo) {
			for (i in exclude)
				if (i.host == info.host && i.port == info.port)
					return true;
			return false;
		}

		if (isClosed)
			onerror("Host is closed");
		else {
			exclude = exclude ?? [];
			for (client in clients)
				if (!ex(client.remote))
					client.send(data);
		}
	}

	final function receiveData(data:Bytes):Void {
		return;
	}

	override function tick():Bool {
		try {
			if (Socket.select([socket], [], [], 0.01).read.length > 0)
				handleClient(socket.accept());
			return true;
		} catch (e)
			if (onerror != null)
				onerror('Failed to tick: ${e.message}');
		return false;
	}

	function handleClient(socket:Socket):Void {
		if (socket != null) {
			var peer = socket.peer();
			var client = new C(Std.string(peer.host), peer.port, false);
			client.isClosed = false;
			client.socket = socket;
			client.local = local;
			client.onmessage = m -> onClientMessage(client, m);
			client.onclose = () -> {
				clients.remove(client);
				onClientClose(client);
			};
			clients.push(client);
			onClientOpen(client);
			client.process();
		}
	}

}
#end
