package snet.tcp;

#if (nodejs || sys)
typedef TCPClient = snet.internal.Client;
#end
