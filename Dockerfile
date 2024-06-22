# Use the Nano Server 20H2 image as the base image
FROM mcr.microsoft.com/windows/nanoserver:20H2

# Set the shell to PowerShell
SHELL ["powershell", "-Command"]

# Install Chocolatey package manager
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install RDP wrapper library to enable multiple RDP sessions
RUN choco install rdpwrap -y

# Download Windows 10 ISO image
RUN Invoke-WebRequest -Uri 'https://software-download.microsoft.com/download/sg/203f59bf-e6ea-484e-8910-27bb5fd984b6/source/19043.2006.210508-0602.vb_release_svc_prod1_Windows_10_Pro_V2004_v2_English_x64.iso' -OutFile $env:TEMP\win10.iso

# Create a new virtual machine with a dynamic VHDX disk
RUN New-VHD -Path $env:TEMP\win10.vhdx -Dynamic -SizeBytes 64GB; `
    $Disk = Get-VHD $env:TEMP\win10.vhdx; `
    $Disk | Add-VMFirmware; `
    $ComputerName = "Win10VM"; `
    $OS = New-Object -ComObject Microsoft.Windows.ServerManager.Smbios; `
    $OS.Reset(); `
    $OS.System.Manufacturer = "Microsoft Corporation"; `
    $OS.System.Name = $ComputerName; `
    $OS.System.Version = "10.0"; `
    $OS.System.SerialNumber = "000000000000"; `
    $OS.System.UUID = (New-Object -TypeName System.Guid).Guid; `
    $VM = New-VM -Name $ComputerName -MemoryStartupBytes 4GB -NewVHDPath $env:TEMP\win10.vhdx -SwitchName "NatNetwork"; `
    Add-VMNetworkAdapter -VMName $ComputerName -SwitchName "NatNetwork"; `
    Set-VMFirmware -VMName $ComputerName -FirstLogonAccount $ComputerName -FirstLogonPassword (ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force); `
    Set-VMProcessor -VMName $ComputerName -Count 2 -EnabledDefaults

# Install Windows 10 and configure the virtual machine
RUN $ISO = Get-VHD $env:TEMP\win10.iso; `
    $VM = Get-VM -Name $ComputerName; `
    Mount-VHD -Path $env:TEMP\win10.vhdx -Password (ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force); `
    Start-VM -Name $ComputerName; `
    while ((Get-VM -Name $ComputerName).State -ne 'Running') { Start-Sleep -Seconds 1 }; `
    Set-VMFirmware -VMName $ComputerName -EnableSecureBoot Off; `
    Set-VMGuest -VMName $ComputerName -ThemesPath "C:\Windows\System32\oobe\info\backgrounds" -GuestOSId "Windows10" -ClrDrainDelay 5000 -ClrDrainThreshold 50 -DefaultFrontBufferHeight 1080 -DefaultFrontBufferWidth 1920 -HPETClock 64 -HypervisorEnlightenment -HypervisorEnlightenmentBeforeReset -TimeSynchronizationOn -IOMMUEnlightenment -IOMMUEnlightenmentBeforeReset -Reset -ResetType Soft; `
    while ((Get-VM -Name $ComputerName).State -ne 'Off') { Start-Sleep -Seconds 1 }; `
    Dismount-VHD -Path $env:TEMP\win10.vhdx; `
    Remove-Item $env:TEMP\win10.iso; `
    Remove-Item $env:TEMP\win10.vhdx

# Expose RDP port
EXPOSE 3389
