1. In Azure Portal, select the tenant, register app (popmsdnapp) and write down its App ID (Client ID)
2. In the registered app, select "API permissions", and "add a permission" with Microsoft.Graph, User.Read.All
3. Do not forget to select "Grant Admin consent for PopMSDN"
4. Using the mycert2 as the client certificate

Run
1. run "Developer Command Prompt for VS2019" command window
2. run "dotnet build", if the nuget reports error, run "dotnet nuget add source --name nuget.org https://api.nuget.org/v3/index.json"
3. fill in proper values in appsettings.json
4. run "dotnet run"