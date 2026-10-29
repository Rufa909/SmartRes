using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

internal static class SmartResLauncher
{
    public static int Main(string[] args)
    {
        var script = Path.Combine(AppContext.BaseDirectory, "SmartResLauncher.ps1");
        if (!File.Exists(script))
        {
            var resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("SmartResLauncher.ps1");
            if (resource == null) { Console.Error.WriteLine("Khong tim thay script launcher."); return 1; }
            script = Path.Combine(Path.GetTempPath(), "SmartResLauncher-" + Process.GetCurrentProcess().Id + ".ps1");
            using (var output = File.Create(script)) resource.CopyTo(output);
        }

        var ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
        var quotedArgs = string.Join(" ", Array.ConvertAll(args, a => "\"" + a.Replace("\"", "\\\"") + "\""));
        if (!Array.Exists(args, a => a.Equals("-ProjectRoot", StringComparison.OrdinalIgnoreCase)))
        {
            var projectRoot = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, ".."));
            quotedArgs = "-ProjectRoot \"" + projectRoot + "\" " + quotedArgs;
        }
        var process = Process.Start(new ProcessStartInfo
        {
            FileName = ps,
            Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" " + quotedArgs,
            UseShellExecute = false,
            WorkingDirectory = AppContext.BaseDirectory
        });
        if (process == null) return 1;
        process.WaitForExit();
        var exitCode = process.ExitCode;
        process.Dispose();
        return exitCode;
    }
}
