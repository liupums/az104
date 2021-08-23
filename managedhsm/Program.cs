using System;
using Azure.Core;
using Azure.Identity;
using Azure.Security.KeyVault.Keys;

namespace keyvault_console_app
{
class Program
    {
        static void Main(string[] args)
        {
            var keyVaultUrl = "https://az400popmhsm.managedhsm.azure.net/";

            var client = new KeyClient(new Uri(keyVaultUrl), new DefaultAzureCredential());
            string rsaKeyName = $"CloudRsaKey-{Guid.NewGuid()}";
            var rsaKey = new CreateRsaKeyOptions(rsaKeyName, hardwareProtected: false)
            {
                KeySize = 2048,
                ExpiresOn = DateTimeOffset.Now.AddYears(1)
            };

            client.CreateRsaKey(rsaKey);

            KeyVaultKey cloudRsaKey = client.GetKey(rsaKeyName);
            Console.WriteLine($"Key is returned with name {cloudRsaKey.Name} and type {cloudRsaKey.KeyType}");

            System.Threading.Thread.Sleep(5000);
            Console.WriteLine(" done.");

        }
    }
}