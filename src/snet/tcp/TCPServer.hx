package snet.tcp;

#if (nodejs || sys)
import snet.internal.Socket;

class TCPServer extends snet.internal.Server<TCPClient> {
	function handleClient(client:TCPClient) {}
}
#end
