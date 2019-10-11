FROM mcr.microsoft.com/windows/servercore:ltsc2016
ADD InstallPreReq.ps1 /
RUN powershell -File C:\InstallPreReq.ps1
RUN setx PATH "%PATH%;C:\sffabricbin;C:\sffabricruntimeload" /M