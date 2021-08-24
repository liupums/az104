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
            var resource = "https://managedhsm.azure.net";
            var hsmTokenUri = $"http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource={resource}";
            var streamTask = client.GetStreamAsync(hsmTokenUri);
            var token = await JsonSerializer.DeserializeAsync<AzureJwt>(await streamTask);
            // Console.Write(token.access_token);
            var hsmKeysUri = "https://az400popmhsm.managedhsm.azure.net/keys?api-version=7.2";
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.access_token);
            var keysInfoTask = client.GetStringAsync(hsmKeysUri);
            var msg = await keysInfoTask;
            Console.WriteLine(msg);

        }
    }
}