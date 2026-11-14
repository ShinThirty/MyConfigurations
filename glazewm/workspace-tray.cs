// workspace-tray: the name of GlazeWM's focused workspace, drawn as a tray icon.
// GlazeWM announces focus and workspace changes on its socket at 127.0.0.1:6123; on each one this
// asks it for the workspaces and draws the focused one's name. Until GlazeWM answers it shows a
// dash and tries again every second; once GlazeWM closes the socket, it exits.
//
// build-workspace-tray.ps1 builds it with the C# 5 compiler in .NET Framework 4.8. Keep this file
// ASCII: that compiler reads a file without a BOM in the system code page.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Net.WebSockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

// the name Settings > Personalization > Taskbar > Other system tray icons lists it under
[assembly: AssemblyTitle("GlazeWM workspace")]

static class WorkspaceTray
{
    const string Query = "query workspaces";
    static readonly Color Focused = ColorTranslator.FromHtml("#ebdbb2");  // gruvbox fg
    static readonly Color Waiting = ColorTranslator.FromHtml("#928374");  // gruvbox gray
    static readonly FontFamily Font = new FontFamily("Segoe UI");
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
    static readonly byte[] Buffer = new byte[16384];

    static NotifyIcon tray;
    static IntPtr iconHandle;
    static string shown;

    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr icon);

    [STAThread]
    static void Main()
    {
        bool first;
        using (new Mutex(true, @"Local\glazewm-workspace-tray", out first))
        {
            if (!first) return;
            SetProcessDPIAware();  // so the tray's icon size comes back scaled for the display
            SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
            tray = new NotifyIcon();
            tray.ContextMenu = new ContextMenu(new[] { new MenuItem("Exit", delegate { Application.Exit(); }) });
            Draw("-", Waiting, "Waiting for GlazeWM");
            tray.Visible = true;
            Listen();
            Application.Run();
            tray.Visible = false;
        }
    }

    // Runs on the UI thread: each await resumes through the context Main sets.
    static async void Listen()
    {
        var reached = false;
        while (true)
        {
            using (var socket = new ClientWebSocket())
            {
                socket.Options.Proxy = null;
                try
                {
                    await socket.ConnectAsync(new Uri("ws://127.0.0.1:6123"), CancellationToken.None);
                    reached = true;
                    await Send(socket, "sub -e focus_changed workspace_activated workspace_updated");
                    await Send(socket, Query);
                    while (true)
                    {
                        var message = Json.Deserialize<Dictionary<string, object>>(await Receive(socket));
                        if (Query.Equals(Get(message, "clientMessage")))
                            Show(Get(message, "data") as Dictionary<string, object>);
                        else
                            await Send(socket, Query);  // an event, or the reply to sub
                    }
                }
                catch (Exception e)
                {
                    if (reached)
                    {
                        Application.Exit();
                        return;
                    }
                    Draw("-", Waiting, "Waiting for GlazeWM: " + e.Message);
                }
            }
            await Task.Delay(1000);
        }
    }

    static void Show(Dictionary<string, object> data)
    {
        var workspaces = Get(data, "workspaces") as IEnumerable;
        if (workspaces == null) return;
        foreach (var item in workspaces)
        {
            var workspace = item as Dictionary<string, object>;
            if (!true.Equals(Get(workspace, "hasFocus"))) continue;
            var name = Get(workspace, "displayName") as string;
            if (string.IsNullOrEmpty(name)) name = Get(workspace, "name") as string;
            if (!string.IsNullOrEmpty(name)) Draw(name, Focused, "Workspace " + name);
            return;
        }
    }

    static void Draw(string name, Color color, string tip)
    {
        if (tip.Length > 63) tip = tip.Substring(0, 63);  // the most a tray tooltip takes
        if (tray.Text != tip) tray.Text = tip;
        if (name == shown) return;
        shown = name;
        var size = GetSystemMetrics(49);  // SM_CXSMICON
        using (var bitmap = new Bitmap(size, size))
        using (var graphics = Graphics.FromImage(bitmap))
        using (var digit = new GraphicsPath())
        using (var path = new GraphicsPath())
        using (var format = StringFormat.GenericTypographic)
        using (var matrix = new Matrix())
        using (var brush = new SolidBrush(color))
        {
            var style = (int)FontStyle.Bold;
            digit.AddString("0", Font, style, 100, PointF.Empty, format);
            path.AddString(name, Font, style, 100, PointF.Empty, format);
            var bounds = path.GetBounds();
            // a digit is three quarters of the icon's height; a longer name shrinks to fit its width
            var scale = Math.Min(size * 0.75f / digit.GetBounds().Height, size / Math.Max(bounds.Width, 1));
            matrix.Translate(size / 2f, size / 2f);
            matrix.Scale(scale, scale);
            matrix.Translate(-(bounds.X + bounds.Width / 2), -(bounds.Y + bounds.Height / 2));
            path.Transform(matrix);
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.FillPath(brush, path);
            var handle = bitmap.GetHicon();
            tray.Icon = Icon.FromHandle(handle);
            if (iconHandle != IntPtr.Zero) DestroyIcon(iconHandle);
            iconHandle = handle;
        }
    }

    static object Get(Dictionary<string, object> map, string key)
    {
        object value;
        return map != null && map.TryGetValue(key, out value) ? value : null;
    }

    static Task Send(ClientWebSocket socket, string message)
    {
        var bytes = Encoding.UTF8.GetBytes(message);
        return socket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
    }

    static async Task<string> Receive(ClientWebSocket socket)
    {
        using (var message = new MemoryStream())
        {
            WebSocketReceiveResult result;
            do
            {
                result = await socket.ReceiveAsync(new ArraySegment<byte>(Buffer), CancellationToken.None);
                if (result.MessageType == WebSocketMessageType.Close) throw new WebSocketException("GlazeWM closed the socket");
                message.Write(Buffer, 0, result.Count);
            } while (!result.EndOfMessage);
            return Encoding.UTF8.GetString(message.ToArray());
        }
    }
}
