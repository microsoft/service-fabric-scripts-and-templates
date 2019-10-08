FROM mcr.microsoft.com/windows/servercore:ltsc2019
ADD InstallPreReq.ps1 /
RUN powershell -File C:\InstallPreReq.ps1
RUN setx PATH "%PATH%;C:\SFFabricBin;C:\SFFabricRuntimeLoad" /M