using Uno;
using Uno.Collections;
using Uno.Threading;
using Uno.Testing;

namespace ThreadingTests
{
    public class UnwrappingPromiseTests
    {
        bool _onFulfilledCalled = false;
        bool _onRejectedCalled = false;
        int _rejectedCalled = 0;
        DummyException _dummyException = new DummyException("dummy");


        static Future<int> IntToDoublePromise(int x)
        {
            return new Promise<int>(x*2);
        }


        static int MultiplyWithSeven(int x)
        {
            return x * 7;
        }


        private class PendingPromiseClosure
        {
            public PendingPromiseClosure(Promise<int> pendingPromise)
            {
                _pendingPromise = pendingPromise;
            }


            private Promise<int> _pendingPromise;


            public Future<int> OnResolved(int x)
            {
                return _pendingPromise;
            }
        }

        [Test]
        public void Then_for_resolved_Promise_given_func_arg_returns_Promise()
        {
            var promise = new Promise<int>(6);
            var nextPromise = promise.Then(MultiplyWithSeven);
            Assert.AreEqual(42, nextPromise.Result);
        }

        [Test]
        public void Then_for_resolved_Promise_given_delegate_which_returns_another_resolved_Promise()
        {
            var promise = new Promise<int>(15);
            var nextPromise = promise.Then(IntToDoublePromise);
            Assert.AreEqual(FutureState.Resolved, nextPromise.State);
            Assert.AreEqual(30, nextPromise.Result);
        }


        [Test]
        public void Then_for_resolved_Promise_given_delegate_which_returns_another_unresolved_Promise()
        {
            var promise = new Promise<int>(15);
            var innerPromise = new Promise<int>();
            var nextPromise = promise.Then(new PendingPromiseClosure(innerPromise).OnResolved);
            Assert.AreEqual(FutureState.Pending, nextPromise.State);
            innerPromise.Resolve(1337);
            Assert.AreEqual(FutureState.Resolved, nextPromise.State);
            Assert.AreEqual(1337, nextPromise.Result);
        }
    }
}
