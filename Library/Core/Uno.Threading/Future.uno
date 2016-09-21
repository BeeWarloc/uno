using Uno;

namespace Uno.Threading
{
    public abstract class Future : IDisposable
    {
        public FutureState State { get; protected set; }
        public abstract void Dispose();
        public abstract void Wait();
        public abstract void Cancel(bool shutdownGracefully = false);
        public abstract Future Then(Action onResolved, Action<Exception> onRejected);
    }

    public abstract class Future<T> : Future
    {
        public abstract T Result { get; }
        public abstract Future<T> Then(Action<T> onResolved, Action<Exception> onRejected = null);
        public abstract Future<TResult> Then<TResult>(Func<T, TResult> onResolved, Func<Exception, TResult> onRejected = null);

        public abstract Future<TResult> Then<TResult>(Func<T, Future<TResult>> onResolved,
            Func<Exception, Future<TResult>> onRejected = null);
    }
}
