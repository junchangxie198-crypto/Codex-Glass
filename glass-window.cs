using System;
using System.Runtime.InteropServices;
namespace CodexGlass {
  public static class WindowMaterial {
    [StructLayout(LayoutKind.Sequential)] private struct Margins { public int Left,Right,Top,Bottom; }
    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr window,int attribute,ref int value,int size);
    [DllImport("dwmapi.dll")] private static extern int DwmExtendFrameIntoClientArea(IntPtr window,ref Margins margins);
    [DllImport("shell32.dll",CharSet=CharSet.Unicode)] private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
    public static int SetAppIdentity() {return SetCurrentProcessExplicitAppUserModelID("CodexGlass.Control");}
    public static int Apply(IntPtr window, bool dark) {
      var margins=new Margins{Left=-1,Right=-1,Top=-1,Bottom=-1};
      DwmExtendFrameIntoClientArea(window,ref margins);
      int rounded=2,light=dark ? 1 : 0,backdrop=3;
      DwmSetWindowAttribute(window,33,ref rounded,4);
      DwmSetWindowAttribute(window,20,ref light,4);
      int noBorder=unchecked((int)0xFFFFFFFE);
      DwmSetWindowAttribute(window,34,ref noBorder,4);
      return DwmSetWindowAttribute(window,38,ref backdrop,4);
    }
  }
}
