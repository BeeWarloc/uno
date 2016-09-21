using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;

namespace Uno.Threading
{
    /**
        Uno-side Promise based on the [A+ standard](https://promisesaplus.com/).
        This can be used in multiple ways:
        ## Statically
        You can use the `Run` function to wrap whatever argument-less function you want as a `Promise`, like this:
            bool doStuff()
            {
                //stuff is done
                success = doOtherStuff();
                return success;
            }
            void onSuccess(bool value) 
            {
                //Success!
            }
            void onFail(Exception e)
            {
                // Oh no!
            }
            
            public void DoSomeFancyStuff()
            {
                var promise = Promise.Run(doStuff).Then(onSuccess, onFail);
            }
        ## Make your own promises
        You can also extend `Promise` and handle it yourself. Simply call `Resolve` or `Reject` once you have a result or a failure. The [Native Facebook login example](https://github.com/fusetools/fuse-samples/blob/feature-NativeFacebookLogin/Samples/NativeFacebookLogin/FacebookLogin/FacebookLoginModule.uno) is a good example of this being done in practice.
    
        Notice that `Resolve` and `Reject` are public, so you can also theoretically both resolve and reject promises from elsewhere.
        # Making Promises accessible from JavaScript modules
        A Promise can be wrapped in a @(NativePromise) and fed to a @(NativeModule) through `AddMember`. You can read more about creating custom js modules, and how to populate them with functions and promises, [here](articles:native-interop/native-js-modules.md)
    */
    public class Promise : Future
    {
        private readonly Promise<object> _wrappedPromise;

        internal Promise(Promise<object> wrappedPromise)
        {
            _wrappedPromise = wrappedPromise;
        }

        public Promise()
        {
            this._wrappedPromise = new Promise<object>();
        }

        // Let's just wrap the non-void Promise variant to avoid to much copy-pasting
        // You might consider this lazy, but I actually think this is better.
        // Correctness over performance. There shouldn't be millions of futures per second
        // anyway, if it is then someone is doing something wrong.
        public override void Wait()
        {
            _wrappedPromise.Wait();
        }

        public void Resolve()
        {
            _wrappedPromise.Resolve(null);
        }

        public void Reject(Exception reason)
        {
            _wrappedPromise.Reject(reason);
        }


        public override void Cancel(bool shutdownGracefully = false)
        {
            throw new NotImplementedException();
        }

        public override void Dispose()
        {
            this._wrappedPromise.Dispose();
        }

        public override Future Then(Action onResolved, Action<Exception> onRejected)
        {
            return this._wrappedPromise.Then(onResolved, onRejected);
        }
    }
    public class Promise<T>  : Future<T>
    {
        private T _result;
        private Exception _reason;
        private readonly object _syncLock = new object();
        private readonly IDispatcher _dispatcher;

        private interface IHandler
        {
            // NOTE: Resolve of handler must be expected _not_ to throw any exceptions
            void Resolve(T result);

            // NOTE: Reject of handler must be expected _not_ to throw any exceptions
            void Reject(Exception reason);
        }

        public Promise() : this(null)
        {
        }

        public Promise(IDispatcher dispatcher)
        {
            _dispatcher = dispatcher;
            State = FutureState.Pending;
        }

        public override T Result
        {
            get
            {
                if (State == FutureState.Pending)
                    Wait();
                if (State != FutureState.Resolved)
                    throw new InvalidOperationException("Promise was rejected, unable to get result.");
                return _result;
            }
        }

        public Promise(T result)
        {
            _result = result;
            State = FutureState.Resolved;
        }


        private abstract class ChainedPromiseHandler<TResult> : IHandler
        {
            Promise<TResult> _promise;

            protected ChainedPromiseHandler(Promise<TResult> promise)
            {
                if (promise == null) throw new ArgumentNullException("promise");
                _promise = promise;
            }

            protected abstract bool OnResolved(T result, out TResult nextResult);
            protected abstract bool OnRejected(Exception exception, out TResult nextResult);

            public void Resolve(T result)
            {
                try
                {
                    TResult nextResult;
                    OnResolved(result, out nextResult);
                    _promise.Resolve(nextResult);
                }
                catch (Exception exception)
                {
                    _promise.Reject(exception);
                }
                finally
                {
                    Clear();
                }
            }

            protected virtual void Clear()
            {
                _promise = null;
            }

            public void Reject(Exception reason)
            {
                try
                {
                    TResult nextResult;
                    if (OnRejected(reason, out nextResult))
                    {
                        _promise.Resolve(nextResult);
                    }
                    else
                    {
                        _promise.Reject(reason);
                    }
                }
                catch (Exception exception)
                {
                    _promise.Reject(exception);
                }
                finally
                {
                    Clear();
                }
            }
        }

        private class ChainedActionHandler : ChainedPromiseHandler<T>
        {
            private Action<T> _onResolved;
            private Action<Exception> _onRejected;
            private IDispatcher _dispatcher;

            public ChainedActionHandler(Promise<T> promise, Action<T> onResolved, Action<Exception> onRejected, IDispatcher dispatcher) : base(promise)
            {
                this._onResolved = onResolved;
                this._onRejected = onRejected;
                _dispatcher = dispatcher;
            }

            protected override bool OnResolved(T result, out T nextResult)
            {
                nextResult = result;
                if (_onResolved != null)
                {
                    if (_dispatcher != null)
                    {
                        _dispatcher.Invoke1(_onResolved, result);
                    }
                    else
                    {
                        _onResolved(result);
                    }
                    return true;
                }
                return false;
            }

            protected override bool OnRejected(Exception exception, out T nextResult)
            {
                nextResult = default(T);
                if (_onRejected != null)
                {
                    if (_dispatcher != null)
                    {
                        _dispatcher.Invoke1(_onRejected, exception);
                    }
                    else
                    {
                        _onRejected(exception);
                    }
                    return true;
                }
                return false;
            }

            protected override void Clear()
            {
                base.Clear();
                _onRejected = null;
                _onResolved = null;
                _dispatcher = null;
            }
        }

        private class ChainedActionWithZeroArgsHandler : ChainedPromiseHandler<object>
        {
            private Action _onResolved;
            private Action<Exception> _onRejected;
            private IDispatcher _dispatcher;

            public ChainedActionWithZeroArgsHandler(Promise<object> promise, Action onResolved, Action<Exception> onRejected, IDispatcher dispatcher) : base(promise)
            {
                this._onResolved = onResolved;
                this._onRejected = onRejected;
                this._dispatcher = dispatcher;
            }

            protected override bool OnResolved(T result, out object nextResult)
            {
                nextResult = null;
                if (_onResolved != null)
                {
                    if (_dispatcher != null)
                    {
                        _dispatcher.Invoke(_onResolved);
                    }
                    else
                    {
                        _onResolved();
                    }
                    return true;
                }
                return false;
            }

            protected override bool OnRejected(Exception exception, out object nextResult)
            {
                nextResult = null;
                if (_onRejected != null)
                {
                    if (_dispatcher != null)
                    {
                        _dispatcher.Invoke1(_onRejected, exception);
                    }
                    else
                    {
                        _onRejected(exception);
                    }
                    return true;
                }
                return false;
            }

            protected override void Clear()
            {
                base.Clear();
                _onRejected = null;
                _onResolved = null;
                _dispatcher = null;
            }
        }


        private class ChainedFuncHandler<TResult> : ChainedPromiseHandler<TResult>
        {
            private Func<T, TResult> _onResolved;
            private Func<Exception, TResult> _onRejected;
            private IDispatcher _dispatcher;

            public ChainedFuncHandler(Promise<TResult> promise, Func<T, TResult> onResolved, Func<Exception, TResult> onRejected, IDispatcher dispatcher) : base(promise)
            {
                this._onResolved = onResolved;
                this._onRejected = onRejected;
                this._dispatcher = dispatcher;
            }

            protected override bool OnResolved(T result, out TResult nextResult)
            {
                nextResult = default(TResult);
                if (_onResolved != null)
                {
                    nextResult = _dispatcher != null ?
                        _dispatcher.Invoke1(_onResolved, result) : _onResolved(result);
                    return true;
                }
                return false;
            }

            protected override bool OnRejected(Exception exception, out TResult nextResult)
            {
                nextResult = default(TResult);
                if (_onRejected != null)
                {
                    nextResult = _dispatcher != null ?
                        _dispatcher.Invoke1(_onRejected, exception) : _onRejected(exception);
                    return true;
                }
                return false;
            }

            protected override void Clear()
            {
                base.Clear();
                _onRejected = null;
                _onResolved = null;
                _dispatcher = null;
            }
        }

        private class WaitPromiseHandler : IHandler, IDisposable
        {
            readonly ManualResetEvent _resetEvent = ManualResetEvent.Create(false);

            public void Resolve(T result)
            {
                _resetEvent.Set();
            }

            public void Reject(Exception reason)
            {
                _resetEvent.Set();
            }

            public void Dispose()
            {
                _resetEvent.Dispose();
            }

            public void Wait()
            {
                _resetEvent.WaitOne();
            }
        }

        private class UnwrappingPromiseHandler<TResult> : IHandler
        {
            private Func<T, Future<TResult>> _onResolved;
            private Func<Exception, Future<TResult>> _onRejected;
            private IDispatcher _dispatcher;
            private Promise<TResult> _promise;

            public UnwrappingPromiseHandler(Promise<TResult> promise, Func<T, Future<TResult>> onResolved, Func<Exception, Future<TResult>> onRejected, IDispatcher dispatcher)
            {
                _onResolved = onResolved;
                _onRejected = onRejected;
                _dispatcher = dispatcher;
                _promise = promise;
            }

            public void Resolve(T result)
            {
                try
                {
                    if (_onResolved != null)
                    {
                        var innerPromise =
                            _dispatcher != null
                                ? _dispatcher.Invoke1(_onResolved, result)
                                : _onResolved(result);
                        if (innerPromise == null)
                            throw new InvalidOperationException("Promise was supposed to return a new promise, but returned null.");
                        innerPromise.Then(InnerResolved, InnerRejected);
                    }
                }
                catch (Exception exception)
                {
                    _promise.Reject(exception);
                }
                finally
                {
                    _onResolved = null;
                    _onRejected = null;
                    _dispatcher = null;
                }
            }

            public void Reject(Exception reason)
            {
                try
                {
                    if (_onRejected != null)
                    {
                        var innerPromise =
                            _dispatcher != null
                                ? _dispatcher.Invoke1(_onRejected, reason)
                                : _onRejected(reason);
                        if (innerPromise == null)
                            throw new InvalidOperationException("Promise was supposed to return a new promise, but returned null.");
                        innerPromise.Then(InnerResolved, InnerRejected);
                    }
                }
                catch (Exception exception)
                {
                    _promise.Reject(exception);
                }
                finally
                {
                    _onResolved = null;
                    _onRejected = null;
                    _dispatcher = null;
                }
            }

            private void InnerResolved(TResult result)
            {
                if (_promise == null)
                    throw new InvalidOperationException("Attempt to resolve promise twice.");
                try
                {
                    _promise.Resolve(result);
                }
                finally
                {
                    _promise = null;
                }
            }

            private void InnerRejected(Exception reason)
            {
                if (_promise == null)
                    throw new InvalidOperationException("Attempt to resolve promise twice.");
                try
                {
                    _promise.Reject(reason);
                }
                finally
                {
                    _promise = null;
                }
            }
        }




        public override void Wait()
        {
            // We could also add a waitHandle to the promise itself.
            using (var waitHandler = new WaitPromiseHandler())
            {
                // Accessing displosed closure.. this is fine as long as we are confident
                // the handler will only be called once.
                Then((IHandler)waitHandler);
                waitHandler.Wait();
            }
        }

        public override void Cancel(bool shutdownGracefully = false)
        {
            throw new NotImplementedException();
        }

        public override void Dispose()
        {
            // Shouldn't really have to do anything here.
            // Used to have to dispose mutex, but when using lock this should be GC'ed?
        }


        public override Future Then(Action onResolved, Action<Exception> onRejected)
        {
            var wrappedPromise = new Promise<object>();
            var promise = new Uno.Threading.Promise(wrappedPromise);
            Then((IHandler)new ChainedActionWithZeroArgsHandler(wrappedPromise, onResolved, onRejected, _dispatcher));
            return promise;
        }

        public void Resolve(T result)
        {
            Queue<IHandler> pendingHandlers = null;
            lock (_syncLock)
            {
                if (State != FutureState.Pending)
                    throw new InvalidOperationException("A promise can't be resolved or rejected multiple times.");
                pendingHandlers = _handlers;
                _result = result;
                _handlers = null;
                State = FutureState.Resolved;
            }

            while (pendingHandlers.Count > 0)
            {
                var handler = pendingHandlers.Dequeue();
                handler.Resolve(result);
            }
        }

        public void Reject(Exception reason)
        {
            Queue<IHandler> pendingHandlers = null;
            lock (_syncLock)
            {
                if (State != FutureState.Pending)
                    throw new InvalidOperationException("A promise can't be resolved or rejected multiple times.");
                pendingHandlers = _handlers;
                _reason = reason;
                _handlers = null;
                State = FutureState.Rejected;
            }

            while (pendingHandlers.Count > 0)
            {
                var handler = pendingHandlers.Dequeue();
                handler.Reject(_reason);
            }
        }

        private Queue<IHandler> _handlers = new Queue<IHandler>();

        public override Future<T> Then(Action<T> onResolved, Action<Exception> onRejected = null)
        {
            var nextPromise = new Promise<T>();
            Then((IHandler)new ChainedActionHandler(nextPromise, onResolved, onRejected, _dispatcher));
            return nextPromise;
        }

        public override Future<TResult> Then<TResult>(Func<T, TResult> onResolved, Func<Exception, TResult> onRejected = null)
        {
            var nextPromise = new Promise<TResult>();
            Then((IHandler)new ChainedFuncHandler<TResult>(nextPromise, onResolved, onRejected, _dispatcher));
            return nextPromise;
        }

        public override Future<TResult> Then<TResult>(Func<T, Future<TResult>> onResolved, Func<Exception, Future<TResult>> onRejected = null)
        {
            var nextPromise = new Promise<TResult>();
            Then((IHandler)new UnwrappingPromiseHandler<TResult>(nextPromise, onResolved, onRejected, _dispatcher));
            return nextPromise;
        }

        private void Then(IHandler handler)
        {
            lock (_syncLock)
            {
                if (State == FutureState.Pending)
                {
                    _handlers.Enqueue(handler);
                    return;
                }
            }

            // To avoid any potential deadlock we call the handlers outside the lock.
            // As the promise is no longer pending it will not change anyway, so this should be ok.
            switch (State)
            {
                case FutureState.Resolved:
                    handler.Resolve(_result);
                    break;
                case FutureState.Rejected:
                    handler.Reject(_reason);
                    break;
                default:
                    throw new InvalidOperationException("Promise in unexpected state " + State);
            }
        }

        private class PromiseTaskClosure
        {
            Promise<T> _promise;
            Func<T> _func;

            public PromiseTaskClosure(Promise<T> promise, Func<T> func)
            {
                _promise = promise;
                _func = func;
            }

            public void Run(CancellationToken cancellationToken)
            {
                try
                {
                    var result = _func();
                    _promise.Resolve(result);
                }
                catch (Exception exception)
                {
                    _promise.Reject(exception);
                }
                finally
                {
                    _promise = null;
                    _func = null;
                }
            }
        }

        public static Future<T> Run(IDispatcher dispatcher, Func<T> func)
        {
            var promise = new Promise<T>(dispatcher);
            Task.Run(new PromiseTaskClosure(promise, func).Run);
            return promise;
        }

        public static Future<T> Run(Func<T> func)
        {
            var promise = new Promise<T>();
            Task.Run(new PromiseTaskClosure(promise, func).Run);
            return promise;
        }
    }

}
