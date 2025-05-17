package snet;

#if sys
import haxe.io.Bytes;
import snet.Net;

class TCPClient extends NetClient<Bytes> {
	@async function receiveData(data:Bytes):Void {
		onmessage(data);
	}
}

class TCPHost extends NetHost<Bytes, TCPClient> {}
#end
