// Velatus portable launcher.
//
// A Flutter Windows build is a folder: velatus.exe, flutter_windows.dll and a
// data/ tree. The engine cannot be statically linked into one PE, so the only
// honest single-file build is a self-extracting one. The whole release folder
// is embedded as `payload.zip` by tool/windows_portable/package.ps1.
//
// First launch unpacks into %LOCALAPPDATA%\Velatus\<version> and starts the
// app from there; later launches go straight to the unpacked exe. Settings
// still live in %APPDATA%, so an update to a new version keeps them.

using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;

internal static class Program
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(IntPtr hWnd, string text, string caption, int type);

    private static int Main(string[] args)
    {
        try
        {
            var root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Velatus",
                BuildInfo.Version);
            var exe = Path.Combine(root, "velatus.exe");

            if (!File.Exists(exe))
            {
                Directory.CreateDirectory(root);
                Unpack(root);
            }

            var start = new ProcessStartInfo(exe)
            {
                WorkingDirectory = root,
                UseShellExecute = false,
            };
            if (args.Length > 0)
            {
                start.Arguments = string.Join(" ", args.Select(Quote));
            }
            Process.Start(start);
            return 0;
        }
        catch (Exception error)
        {
            var log = Path.Combine(Path.GetTempPath(), "velatus-portable-error.txt");
            try { File.WriteAllText(log, error.ToString()); } catch { }
            MessageBox(
                IntPtr.Zero,
                "Velatus could not start.\n\n" + error.Message + "\n\nDetails: " + log,
                "Velatus",
                0x10);
            return 1;
        }
    }

    private static void Unpack(string root)
    {
        var assembly = Assembly.GetExecutingAssembly();
        var name = assembly.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith("payload.zip", StringComparison.OrdinalIgnoreCase));
        if (name == null)
        {
            throw new InvalidOperationException("The embedded payload is missing.");
        }

        using (var stream = assembly.GetManifestResourceStream(name))
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
        {
            foreach (var entry in archive.Entries)
            {
                // Backslashes are the Windows separator used by Compress-Archive.
                var relative = entry.FullName.Replace('/', Path.DirectorySeparatorChar);
                var target = Path.Combine(root, relative);
                if (string.IsNullOrEmpty(entry.Name))
                {
                    Directory.CreateDirectory(target);
                    continue;
                }
                var folder = Path.GetDirectoryName(target);
                if (!string.IsNullOrEmpty(folder))
                {
                    Directory.CreateDirectory(folder);
                }
                entry.ExtractToFile(target, true);
            }
        }
    }

    private static string Quote(string value)
    {
        if (value.IndexOfAny(new[] { ' ', '\t', '"' }) < 0)
        {
            return value;
        }
        return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    }
}
