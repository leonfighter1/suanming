# Keeps Windows from sleeping while this process runs (used by `npm run public`).
# SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED) lasts until this
# process exits; the normal sleep timer comes back by itself. No admin rights,
# no power settings changed. The display may still turn off.
Add-Type -Namespace MingLi -Name Power -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
[MingLi.Power]::SetThreadExecutionState([uint32]"0x80000001") | Out-Null
Write-Output "keep-awake: on"
while ($true) { Start-Sleep -Seconds 3600 }
