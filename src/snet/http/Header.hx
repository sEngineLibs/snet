package snet.http;

enum abstract Header(String) from String to String {
	// General headers
	var CACHE_CONTROL = "Cache-Control";
	var CONNECTION = "Connection";
	var DATE = "Date";
	var PRAGMA = "Pragma";
	var TRAILER = "Trailer";
	var TRANSFER_ENCODING = "Transfer-Encoding";
	var UPGRADE = "Upgrade";
	var VIA = "Via";
	var WARNING = "Warning";

	// Request headers
	var ACCEPT = "Accept";
	var ACCEPT_CHARSET = "Accept-Charset";
	var ACCEPT_ENCODING = "Accept-Encoding";
	var ACCEPT_LANGUAGE = "Accept-Language";
	var AUTHORIZATION = "Authorization";
	var EXPECT = "Expect";
	var FROM = "From";
	var HOST = "Host";
	var IF_MATCH = "If-Match";
	var IF_MODIFIED_SINCE = "If-Modified-Since";
	var IF_NONE_MATCH = "If-None-Match";
	var IF_RANGE = "If-Range";
	var IF_UNMODIFIED_SINCE = "If-Unmodified-Since";
	var MAX_FORWARDS = "Max-Forwards";
	var PROXY_AUTHORIZATION = "Proxy-Authorization";
	var RANGE = "Range";
	var REFERER = "Referer";
	var TE = "TE";
	var USER_AGENT = "User-Agent";

	// Response headers
	var ACCEPT_RANGES = "Accept-Ranges";
	var AGE = "Age";
	var ETAG = "ETag";
	var LOCATION = "Location";
	var PROXY_AUTHENTICATE = "Proxy-Authenticate";
	var RETRY_AFTER = "Retry-After";
	var SERVER = "Server";
	var VARY = "Vary";
	var WWW_AUTHENTICATE = "WWW-Authenticate";

	// Entity headers
	var ALLOW = "Allow";
	var CONTENT_ENCODING = "Content-Encoding";
	var CONTENT_LANGUAGE = "Content-Language";
	var CONTENT_LENGTH = "Content-Length";
	var CONTENT_LOCATION = "Content-Location";
	var CONTENT_MD5 = "Content-MD5";
	var CONTENT_RANGE = "Content-Range";
	var CONTENT_TYPE = "Content-Type";
	var EXPIRES = "Expires";
	var LAST_MODIFIED = "Last-Modified";

	// WebSocket headers
	var SEC_WEBSOCKET_KEY = "Sec-WebSocket-Key";
	var SEC_WEBSOCKET_ACCEPT = "Sec-WebSocket-Accept";
	var SEC_WEBSOCKET_VERSION = "Sec-WebSocket-Version";
	var SEC_WEBSOCKET_PROTOCOL = "Sec-WebSocket-Protocol";
	var SEC_WEBSOCKET_EXTENSIONS = "Sec-WebSocket-Extensions";
	var X_WEBSOCKET_REJECT_REASON = "X-WebSocket-Reject-Reason";

	// CORS headers
	var ORIGIN = "Origin";
	var ACCESS_CONTROL_ALLOW_ORIGIN = "Access-Control-Allow-Origin";
	var ACCESS_CONTROL_ALLOW_METHODS = "Access-Control-Allow-Methods";
	var ACCESS_CONTROL_ALLOW_HEADERS = "Access-Control-Allow-Headers";
	var ACCESS_CONTROL_EXPOSE_HEADERS = "Access-Control-Expose-Headers";
	var ACCESS_CONTROL_MAX_AGE = "Access-Control-Max-Age";
	var ACCESS_CONTROL_ALLOW_CREDENTIALS = "Access-Control-Allow-Credentials";
	var ACCESS_CONTROL_REQUEST_METHOD = "Access-Control-Request-Method";
	var ACCESS_CONTROL_REQUEST_HEADERS = "Access-Control-Request-Headers";

	// Security headers
	var STRICT_TRANSPORT_SECURITY = "Strict-Transport-Security";
	var CONTENT_SECURITY_POLICY = "Content-Security-Policy";
	var X_CONTENT_TYPE_OPTIONS = "X-Content-Type-Options";
	var X_FRAME_OPTIONS = "X-Frame-Options";
	var X_XSS_PROTECTION = "X-XSS-Protection";
	var PERMISSIONS_POLICY = "Permissions-Policy";
	var REFERRER_POLICY = "Referrer-Policy";

	// Custom or deprecated but useful
	var X_REQUESTED_WITH = "X-Requested-With";
	var X_FORWARDED_FOR = "X-Forwarded-For";
	var X_FORWARDED_PROTO = "X-Forwarded-Proto";
	var X_REAL_IP = "X-Real-IP";
	var X_POWERED_BY = "X-Powered-By";
	var DNT = "DNT"; // Do Not Track
}
