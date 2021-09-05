using System;
using System.Threading.Tasks;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Collections.Generic;
using System.Text.Json;

namespace vm_identity_console_app
{
    class Program
    {
        private static readonly HttpClient client = new HttpClient();

        static async Task Main(string[] args)
        {
            await Process();
        }
        
        private static async Task Process()
        {
            client.DefaultRequestHeaders.Accept.Clear();
            client.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));
            client.DefaultRequestHeaders.Add("Metadata", "true");
            Console.WriteLine("hsm test");
            var resource = "https://managedhsm.azure.net";
            var hsmTokenUri = $"http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource={resource}";
            var streamTask = client.GetStreamAsync(hsmTokenUri); 
            var token = await JsonSerializer.DeserializeAsync<AzureJwt>(await streamTask);
            Console.Write(token.access_token);
            var hsmKeysUri = "https://az400popmhsm.managedhsm.azure.net/keys?api-version=7.2";
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.access_token);
            var keysInfoTask = client.GetStringAsync(hsmKeysUri); 
            var msg = await keysInfoTask;
            Console.WriteLine(msg);
            Console.WriteLine("az400popliukeyvault key valut key test");
            resource = "https://vault.azure.net"; //for key vault 
            var clientId = "8a188a88-fd90-41e9-b603-fe949e2eaf22"; // user-assigned managed identity
            // https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-use-vm-token
            /*
            client_id	(Optional) A query string parameter, 
            indicating the client_id of the managed identity you would like the token for. 
            Required, if your VM has multiple user-assigned managed identities.
            */
            var kvTokenUri = $"http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource={resource}&client_id={clientId}";
            var kvStreamTask = client.GetStreamAsync(kvTokenUri); 
            var kvToken = await JsonSerializer.DeserializeAsync<AzureJwt>(await kvStreamTask);
            var secretUri = "https://az400popliukeyvault.vault.azure.net/keys/myimportrsakey?api-version=7.2";
            Console.Write(kvToken.access_token);
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", kvToken.access_token);
            var secretInfoTask = client.GetStringAsync(secretUri); 
            var clearSecret = await secretInfoTask;
            Console.WriteLine(clearSecret);


        }
    }
}
