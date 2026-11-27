# `quds:async` Reference

Structured concurrency primitives for Quds (Dart VM & JavaScript/Web parity).

```quds
use quds:async
```

## Cancellation

- `CancelledException(reason: String)`
- `CancellationSource` — `token()`, `isCancelled()`, `cancel([reason])`, `cancelAfter(delay, reason: ...)`, `dispose()` (works with `using`)
- `CancellationToken` — `isCancelled()`, `reason()`, `throwIfCancelled()`, `onCancel(cb)`, `whenCancelled()`
- `withCancellation<T>(token, task)` — fails immediately with `CancelledException` if cancelled

## Timeouts & Retry

- `AsyncTimeoutException(duration: Duration, message: String)`
- `withTimeout<T>(duration, task, message: ...)` — cancels its timer cleanly on task completion
- `withTimeoutOrNull<T>(duration, task)` — returns `null` on timeout
- `retryAsync<T>(maxAttempts, delay, task, backoffFactor: 1.0, token: null)` — cancellable exponential-backoff retry passing 1-indexed `attempt`
- `sleep(duration: Duration)`

## Coordination & Combinators

- `Semaphore(permits: int)` — FIFO permits, compatible with `lock sem:` (`available()`, `waiting()`, `tryAcquire()`, `acquire()`, `release()`)
- `AsyncGate(initialOpen: bool = false)` — manual-reset barrier (`isOpen()`, `open()`, `close()`, `wait()`)
- `waitAll<T>(tasks)` — awaits all futures preserving order
- `race<T>(tasks)` — resolves/rejects with the first settled future
- `mapConcurrent<T, R>(items, concurrency, worker)` — bounded-concurrency mapper preserving input order

## Channels & Event Timing

- `Channel<T>(capacity: int = 0)` — unbounded or bounded FIFO channel with sender backpressure (`trySend`, `send`, `tryReceive`, `receive`, `receiveOrNull`, `close`, `dispose`)
- `drainChannel<T>(channel)` — drains all remaining items until closed
- `BroadcastChannel<T>(subscriberCapacity: int = 0)` — fan-out pub/sub (`subscribe()`, `unsubscribe()`, `publish()`, `subscriberCount()`, `close()`, `dispose()`)
- `Debouncer(delay: Duration)` — timer-backed debounce (`call()`, `isPending()`, `cancel()`, `dispose()`)
- `Throttler(interval: Duration)` — leading-edge throttle (`tryRun()`, `reset()`)

## Tests

- Primary Quds suite: `test/async_sdk.quds` (`quds test test/async_sdk.quds`)
- VM + JS parity & embedded sync: `test/async_sdk_test.dart`
