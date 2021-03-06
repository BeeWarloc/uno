using Uno.Compiler.ExportTargetInterop;
using Uno.Runtime.Implementation;
using System;

namespace Uno.Diagnostics
{
    [extern(DOTNET) DotNetType]
    public enum DebugMessageType
    {
        Debug,
        Information,
        Warning,
        Error,
        Fatal,

        [Obsolete("Use 'DebugMessageType.Debug' instead")]
        Undefined = 0,
    }

    [extern(DOTNET) DotNetType]
    public delegate void AssertionHandler(bool value, string expression, string filename, int line, params object[] operands);

    [extern(DOTNET) DotNetType]
    public delegate void LogHandler(string message, DebugMessageType type);

    [extern(DOTNET) DotNetType]
    public static class Debug
    {
        // TODO: Deprecated
        static AssertionHandler _assertionHandler;

        // TODO: Deprecated
        public static void SetAssertionHandler(AssertionHandler handler)
        {
            _assertionHandler = handler;
        }

        // TODO: Deprecated
        public static void Assert(bool value, string expression, string filename, int line, params object[] operands)
        {
            if (_assertionHandler != null)
            {
                _assertionHandler(value, expression, filename, line, operands);
            }
            if (!value)
            {
                EmitLog("Assertion Failed: '" + expression + "' in " + filename + "(" + line + ")", DebugMessageType.Error);
            }
        }

        static LogHandler _logHandler;

        public static void SetLogHandler(LogHandler handler)
        {
            _logHandler = handler;
        }

        public static void Log(string message, DebugMessageType type, string filename, int line)
        {
            EmitLog(message, type);
        }

        public static void Log(object message, DebugMessageType type, string filename, int line)
        {
            EmitLog((message ?? string.Empty).ToString(), type);
        }

        public static void Log(string message, DebugMessageType type = 0)
        {
            EmitLog(message, type);
        }

        public static void Log(object message, DebugMessageType type = 0)
        {
            EmitLog(message.ToString(), type);
        }

        static string _indentStr = "";
        public static void IndentLog()
        {
            _indentStr += "\t";
        }

        public static void UnindentLog()
        {
            _indentStr = _indentStr.Substring( 0, _indentStr.Length - 1 );
        }

        static void EmitLog(string message, DebugMessageType type)
        {
            if (_logHandler != null)
                _logHandler(_indentStr + message, type);

            if defined(CPLUSPLUS)
            @{
                uCString cstr($0);
                uLog($1, "%s", cstr.Ptr);
            @}
            else if defined(DOTNET)
            {
                if (type == 0)
                    Console.WriteLine(message);
                else if ((int) type < DebugMessageType.Warning)
                    Console.Out.WriteLine(type + ": " + message);
                else
                    Console.Error.WriteLine(type + ": " + message);
            }
            else if defined(JAVASCRIPT)
            @{
                console.log($0);
            @}
            else
                build_error;
        }

        [Obsolete]
        public static void Alert(string message, string caption, DebugMessageType type)
        {
            if defined(CPLUSPLUS)
            {
            }
            else if defined(DOTNET)
            {
            }
            else if defined(JAVASCRIPT)
            @{
                alert($0);
            @}
            else
                build_error;
        }

        [Obsolete]
        public static void Alert(string message)
        {
            // TODO: Get caption from application
            Alert(message, "Alert", 0);
        }

        [Obsolete]
        public static bool Confirm(string message, string caption, DebugMessageType type)
        {
            if defined(CPLUSPLUS)
            {
                // TODO
                return false;
            }
            else if defined(DOTNET)
            {
                return false;
            }
            else if defined(JAVASCRIPT)
            @{
                return confirm($0);
            @}
            else
                build_error;
        }

        [Obsolete]
        public static bool Confirm(string message)
        {
            // TODO: Get caption from application
            return Confirm(message, "Confirm", 0);
        }
    }
}
