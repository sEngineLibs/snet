package snet.http;

/**
 * HTTP status codes.
 */
enum abstract Status(Int) from Int to Int {
	// --- 1xx Informational ---

	/** Request headers received, client should proceed with request body. */
	var Continue = 100;

	/** Server agrees to switch protocols as requested. */
	var SwitchingProtocols = 101;

	/** Request is being processed, no response yet. */
	var Processing = 102;

	/** Sends early response headers before final response. */
	var EarlyHints = 103;

	// --- 2xx Success ---

	/** Request succeeded, response depends on method used. */
	var OK = 200;

	/** Request succeeded and a new resource was created. */
	var Created = 201;

	/** Request accepted but not yet processed. */
	var Accepted = 202;

	/** Request successful, but info may be modified by a proxy. */
	var NonAuthoritativeInformation = 203;

	/** Request successful, but no content is returned. */
	var NoContent = 204;

	/** Request successful, client should reset document view. */
	var ResetContent = 205;

	/** Partial content delivered due to range header. */
	var PartialContent = 206;

	/** Multiple status responses for WebDAV requests. */
	var MultiStatus = 207;

	/** Repeated WebDAV elements not included again. */
	var AlreadyReported = 208;

	/** Response reflects result of instance manipulations. */
	var IMUsed = 226;

	// --- 3xx Redirection ---

	/** Multiple options available for resource. */
	var MultipleChoices = 300;

	/** Resource permanently moved to a new URI. */
	var MovedPermanently = 301;

	/** Resource temporarily moved to a different URI. */
	var Found = 302;

	/** Resource available under a different URI via GET. */
	var SeeOther = 303;

	/** Resource not modified since last requested. */
	var NotModified = 304;

	/** Resource must be accessed through a proxy. */
	var UseProxy = 305;

	/** Status code no longer used. */
	var SwitchProxy = 306;

	/** Temporary redirect, original URI should still be used. */
	var TemporaryRedirect = 307;

	/** Resource permanently moved; method unchanged. */
	var PermanentRedirect = 308;

	// --- 4xx Client Errors ---

	/** Malformed or invalid request. */
	var BadRequest = 400;

	/** Authentication required or failed. */
	var Unauthorized = 401;

	/** Reserved for payment-related errors. */
	var PaymentRequired = 402;

	/** Valid request but action is forbidden. */
	var Forbidden = 403;

	/** Requested resource could not be found. */
	var NotFound = 404;

	/** Request method not supported. */
	var MethodNotAllowed = 405;

	/** Requested content not acceptable. */
	var NotAcceptable = 406;

	/** Proxy authentication required. */
	var ProxyAuthenticationRequired = 407;

	/** Server timed out waiting for request. */
	var RequestTimeout = 408;

	/** Conflict with current resource state. */
	var Conflict = 409;

	/** Resource no longer available. */
	var Gone = 410;

	/** Length of content required but not specified. */
	var LengthRequired = 411;

	/** One or more preconditions failed. */
	var PreconditionFailed = 412;

	/** Payload too large to process. */
	var PayloadTooLarge = 413;

	/** URI is too long to process. */
	var URITooLong = 414;

	/** Media type not supported. */
	var UnsupportedMediaType = 415;

	/** Requested range not satisfiable. */
	var RangeNotSatisfiable = 416;

	/** Expect header requirements not met. */
	var ExpectationFailed = 417;

	/** I'm a teapot; April Fools' joke status. */
	var ImATeapot = 418;

	/** Request sent to the wrong server. */
	var MisdirectedRequest = 421;

	/** Well-formed but unprocessable content. */
	var UnprocessableContent = 422;

	/** Resource is currently locked. */
	var Locked = 423;

	/** Request failed due to a dependency. */
	var FailedDependency = 424;

	/** Request received too early. */
	var TooEarly = 425;

	/** Upgrade protocol required. */
	var UpgradeRequired = 426;

	/** Request must be conditional. */
	var PreconditionRequired = 428;

	/** Too many requests in a given time. */
	var TooManyRequests = 429;

	/** Request header fields too large. */
	var RequestHeaderFieldsTooLarge431 = 431;

	/** Resource unavailable due to legal reasons. */
	var UnavailableForLegalReasons = 451;

	// --- 5xx Server Errors ---

	/** Generic server error. */
	var InternalServerError = 500;

	/** Server does not support the request method. */
	var NotImplemented = 501;

	/** Invalid response from upstream server. */
	var BadGateway = 502;

	/** Server is temporarily overloaded or down. */
	var ServiceUnavailable = 503;

	/** Gateway timed out waiting for response. */
	var GatewayTimeout = 504;

	/** HTTP version not supported. */
	var HTTPVersionNotSupported = 505;

	/** Circular content negotiation. */
	var VariantAlsoNegotiates = 506;

	/** Server lacks storage to complete request. */
	var InsufficientStorage = 507;

	/** Infinite loop detected while processing. */
	var LoopDetected = 508;

	/** Request needs further extensions. */
	var NotExtended = 510;

	/** Network authentication required. */
	var NetworkAuthenticationRequired = 511;

	// --- Unofficial Codes & Extensions ---

	/** Generic success code used by Apache. */
	var ThisIsFine = 218;

	/** Session expired (Laravel). */
	var PageExpired = 419;

	/** Method failure (Spring/WebDAV). */
	var MethodFailure = 420;

	/** Client is being rate-limited (Twitter). */
	var EnhanceYourCalm = 420;

	/** Shopify rate-limit variant. */
	var RequestHeaderFieldsTooLarge430 = 430;

	/** Request rejected as malicious. */
	var ShopifySecurityRejection = 430;

	/** Blocked by parental controls. */
	var BlockedByWindowsParentalControls = 450;

	/** Token expired or invalid. */
	var InvalidToken = 498;

	/** Token required but not provided. */
	var TokenRequired = 499;

	/** Bandwidth exceeded limit. */
	var BandwidthLimitExceeded = 509;

	/** Server is overloaded (Qualys). */
	var SiteIsOverloaded = 529;

	/** Site frozen or suspended. */
	var SiteIsFrozen = 530;

	/** Cloudflare DNS resolution failed. */
	var OriginDNSError = 530;

	/** Endpoint temporarily disabled. */
	var TemporarilyDisabled = 540;

	/** Proxy network read timeout. */
	var NetworkReadTimeoutError = 598;

	/** Network connect timeout. */
	var NetworkConnectTimeoutError = 599;

	/** JSON syntax error in request. */
	var UnexpectedToken = 783;

	/** Non-standard or unknown error. */
	var NonStandard = 999;

	// --- IIS & Load Balancers ---

	/** Session expired, re-login required. */
	var LoginTimeout = 440;

	/** Retry request with additional info. */
	var RetryWith = 449;

	/** Redirect in Exchange ActiveSync. */
	var Redirect451 = 451;

	/** Server closes connection with no response. */
	var NoResponse = 444;

	/** Request header too large. */
	var RequestHeaderTooLarge = 494;

	/** Invalid SSL certificate provided. */
	var SSLCertificateError = 495;

	/** Required SSL certificate missing. */
	var SSLCertificateRequired = 496;

	/** HTTP sent to HTTPS port. */
	var HTTPRequestSentToHTTPSPort = 497;

	/** Client closed request before response. */
	var ClientClosedRequest = 499;

	/** Unknown server error from Cloudflare. */
	var WebServerReturnedAnUnknownError = 520;

	/** Server is down and unreachable. */
	var WebServerIsDown = 521;

	/** Cloudflare timed out contacting server. */
	var ConnectionTimedOut = 522;

	/** Cloudflare unable to reach server. */
	var OriginIsUnreachable = 523;

	/** TCP connection made, but no response. */
	var ATimeoutOccurred = 524;

	/** SSL handshake with origin failed. */
	var SSLHandshakeFailed = 525;

	/** Invalid SSL certificate at origin. */
	var InvalidSSLCertificate = 526;

	/** Cloudflare could not resolve hostname. */
	var CloudflareUnableToResolveOriginHostname = 530;

	/** Header compression too large or many requests. */
	var ElasticLoadBalancingCode000 = 0;

	/** Client closed connection before timeout. */
	var ClientClosedLoadBalancerConnection = 460;

	/** Too many IPs in X-Forwarded-For header. */
	var XForwardedForTooManyIPs = 463;

	/** Client and server use incompatible protocols. */
	var IncompatibleProtocolVersions = 464;

	/** Authentication failed at load balancer. */
	var UnauthorizedLoadBalancerAuthenticationError = 561;
}
