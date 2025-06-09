package snet.internal;

#if (sys && target.threaded)
import sys.thread.Thread;
import sys.thread.EventLoop;
#end
import sasync.Lazy;

class Background {
	public static function run<T>(f:Void->T):Lazy<T> {
		#if (sys && target.threaded)
		static var pool:Array<EventLoop> = [];
		static var promised:Bool = false;

		if (!promised)
			Thread.current().events.promise();

		return new Lazy<T>((resolve, reject) -> {
			if (pool.length == 0) {
				var lock = new sys.thread.Lock();
				Thread.createWithEventLoop(() -> {
					var events = Thread.current().events;
					events.promise();
					pool.push(events);
					lock.release();
				});
				lock.wait();
			}
			var events = pool.pop();
			events.promise();
			events.runPromised(() -> {
				try {
					resolve(f());
				} catch (e)
					reject(e);
				if (pool.length == 0)
					pool.push(events);
				else
					events.runPromised(() -> {});
			});
		});
		#else
		return new Lazy((resolve, _) -> resolve(f()));
		#end
	}
}
