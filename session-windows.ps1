# Preserve MSIX identity by activating the registered app, rather than executing its file.
if (-not ('CodexGlass.PackagedApp' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace CodexGlass {
  public static class PackagedApp {
    [DllImport("kernel32.dll", SetLastError=true)] private static extern IntPtr OpenProcess(uint access, bool inherit, uint processId);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] private static extern int GetPackageFullName(IntPtr process, ref uint length, StringBuilder name);
    public static string PackageName(uint processId) {
      IntPtr handle=OpenProcess(0x1000,false,processId);
      if(handle==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
      try {
        uint length=0;
        int error=GetPackageFullName(handle,ref length,null);
        if(error==15700) return null;
        if(error!=122) throw new Win32Exception(error);
        var name=new StringBuilder((int)length);
        error=GetPackageFullName(handle,ref length,name);
        if(error!=0) throw new Win32Exception(error);
        return name.ToString();
      } finally {CloseHandle(handle);}
    }
    public static uint Activate(string aumid, int port) {
      if(aumid!="OpenAI.Codex_2p2nqsd0c76g0!App" || port<1024 || port>65535) throw new ArgumentException("Invalid official app or port");
      object instance=Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C"),true));
      try {
        uint processId;
        int result=((IApplicationActivationManager)instance).ActivateApplication(aumid,"--remote-debugging-address=127.0.0.1 --remote-debugging-port="+port,0,out processId);
        Marshal.ThrowExceptionForHR(result);
        return processId;
      } finally {if(Marshal.IsComObject(instance)) Marshal.FinalReleaseComObject(instance);}
    }
    [ComImport,Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IApplicationActivationManager {
      [PreserveSig] int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string aumid,[MarshalAs(UnmanagedType.LPWStr)] string arguments,uint options,out uint processId);
      [PreserveSig] int ActivateForFile([MarshalAs(UnmanagedType.LPWStr)] string aumid,IntPtr items,[MarshalAs(UnmanagedType.LPWStr)] string verb,out uint processId);
      [PreserveSig] int ActivateForProtocol([MarshalAs(UnmanagedType.LPWStr)] string aumid,IntPtr items,out uint processId);
    }
  }
}
'@
}
function Get-GlassVerifiedCdpIdentity {
  param([int]$Port,[Parameter(Mandatory=$true)][object]$Codex)
  $listeners=@(Get-DreamSkinPortListeners -Port $Port)
  if($listeners.Count -eq 0){return $null}
  foreach($listener in $listeners){
    try {
      if([CodexGlass.PackagedApp]::PackageName([uint32]$listener.OwningProcess) -cne $Codex.PackageFullName){return $null}
    } catch {return $null}
  }
  # Still require loopback-only listeners, registered executable path and browser identity.
  return Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $Codex
}
function Get-GlassCodexAumid {
  param([Parameter(Mandatory=$true)][object]$Codex)
  $aumid=$Codex.PackageFamilyName+'!App'
  if($aumid -cne 'OpenAI.Codex_2p2nqsd0c76g0!App'){throw 'Unexpected Codex application identity'}
  $package=Get-AppxPackage -Name OpenAI.Codex | Where-Object {$_.PackageFullName -ceq $Codex.PackageFullName} | Select-Object -First 1
  if($null -eq $package){throw 'The registered Codex package changed before activation'}
  $manifest=Get-AppxPackageManifest -Package $package
  $app=@($manifest.Package.Applications.Application | Where-Object {$_.Id -ceq 'App' -and ($_.Executable -replace '\\','/') -eq 'app/ChatGPT.exe'})
  if($app.Count -ne 1){throw 'The official Codex app entry could not be verified'}
  return $aumid
}
function Start-GlassPackagedCodex {
  param([int]$Port,[Parameter(Mandatory=$true)][object]$Codex)
  $aumid=Get-GlassCodexAumid -Codex $Codex
  return [CodexGlass.PackagedApp]::Activate($aumid,$Port)
}
