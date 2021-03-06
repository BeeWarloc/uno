﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Stuff.Format;
using Uno.Diagnostics;
using Uno.IO;
using Uno.Macros;

namespace Uno.Configuration
{
    public class UnoConfigFile
    {
        public static readonly HashSet<string> Defines = new HashSet<string>(EnumerateDefines());
        public static readonly Dictionary<string, string> Constants = new Dictionary<string, string>
        {
#if DEBUG
            {"Configuration", "Debug"}
#else
            {"Configuration", "Release"}
#endif
        };

        static IEnumerable<string> EnumerateDefines()
        {
            return UnoVersion.IsDevBuild
                ? StuffFile.DefaultDefines.Concat(new[] {"DEV"})
                : StuffFile.DefaultDefines;
        }

        public readonly StuffFile Stuff;
        StuffMap _data;

        internal UnoConfigFile(string filename)
        {
            Stuff = new StuffFile(filename, Defines);
        }

        public StuffMap GetData()
        {
            if (_data != null)
                return _data;

            if (Stuff != null)
            {
                try
                {
                    lock (Stuff)
                    {
                        if (_data != null)
                            return _data;

                        Stuff.Parse(File.ReadAllText(Stuff.Filename));
                        _data = Stuff.Flatten(File.ReadAllText);

                        foreach (var e in _data)
                            for (var item = e.Value; item != null; item = item.Next)
                                 Update(ref item);
                    }
                }
                catch (Exception e)
                {
                    Console.Error.WriteLine("ERROR: " + Stuff.Filename.ToRelativePath() + ": " + e.Message);
                }
            }

            return _data ?? (_data = new StuffMap());
        }

        void Update(ref StuffItem item)
        {
            if (item.Value == null)
                return;

            item.Value = MacroParser.Expand(Source.Unknown, item.Value, false, null, GetConstant, "$(", ')');

            if (Path.DirectorySeparatorChar == '\\' && item.Value.IsFullPath())
                item.Value = item.Value.UnixToNative();
        }

        public override string ToString()
        {
            return Stuff.Filename;
        }

        string GetConstant(Source src, string key, object context)
        {
            string result;
            Constants.TryGetValue(key, out result);
            return result;
        }
    }
}