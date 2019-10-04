FROM microsoft/windowsservercore:latest
ADD InstallPreReq.ps1 /
RUN powershell -File C:\InstallPreReq.ps1
RUN setx PATH "%PATH%;C:\SFFabricBin;C:\SFFabricRuntimeLoad" /M