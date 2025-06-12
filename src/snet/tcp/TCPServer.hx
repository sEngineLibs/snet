package snet.tcp;

#if (nodejs || sys)
typedef TCPServer = snet.internal.Server<TCPClient>;
#end
