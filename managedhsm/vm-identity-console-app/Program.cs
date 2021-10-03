using System;
using System.Threading.Tasks;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Collections.Generic;
using System.Text.Json;
using System.Text;
using Azure.Security.KeyVault.Keys;
using Azure.Security.KeyVault.Keys.Cryptography;
using Azure.Identity;

namespace vm_identity_console_app
{
    class Program
    {
        private static readonly HttpClient client = new HttpClient();

        static async Task Main(string[] args)
        {
            await ProcessEncryptDecrypt();
            await Process();
        }
        
        static void CreateHsmKey()
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

        private static async Task ProcessEncryptDecrypt()
        {
            var keyVaultUrl = "https://az400popmhsm.managedhsm.azure.net/";
            var keyName = "mypemrsakey";
            var clientCredential  =  new DefaultAzureCredential();
            var keyClient = new KeyClient(new Uri(keyVaultUrl), clientCredential);
            var key = await keyClient.GetKeyAsync(keyName);
            Console.WriteLine("Test with CryptographyClient");
            // create CryptographyClient
            CryptographyClient cryptoClient = new CryptographyClient(key.Value.Id, clientCredential);
            Console.WriteLine("Key id :" + key.Value.Id);

            var str ="5ka5IVsnGrzufA";
            Console.WriteLine("The String used to be encrypted is :  " +str );

            Console.WriteLine("-------------encrypt---------------");
            var byteData = Encoding.Unicode.GetBytes(str);
            var encryptResult = await cryptoClient.EncryptAsync(EncryptionAlgorithm.Rsa15, byteData);
            var encodedText = Convert.ToBase64String(encryptResult.Ciphertext);
            Console.WriteLine(encodedText);

            Console.WriteLine("-------------dencrypt---------------");
            var encryptedBytes = Convert.FromBase64String(encodedText);
            var dencryptResult = await cryptoClient.DecryptAsync(EncryptionAlgorithm.Rsa15, encryptedBytes);
            var decryptedText = Encoding.Unicode.GetString(dencryptResult.Plaintext);
            Console.WriteLine(decryptedText);
        }

        private static async Task GetTokenFromIMDS()
        {
            client.DefaultRequestHeaders.Accept.Clear();
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            client.DefaultRequestHeaders.Add("Metadata", "true");
            Console.WriteLine("Try to get access token");
            var resource = "https://managedhsm.azure.net";
            var hsmTokenUri = $"http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource={resource}";
            var streamTask = client.GetStreamAsync(hsmTokenUri); 
            var token = await JsonSerializer.DeserializeAsync<AzureJwt>(await streamTask);
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.access_token);
            Console.WriteLine("Successfully get access token");
        }

        private static async Task Process()
        {
            Console.WriteLine("\n----\nTest with REST API---\n");
            await GetTokenFromIMDS();
            Console.WriteLine("\n----\nTest Encryption---\n");
            var keyVaultUrl = "https://az400popmhsm.managedhsm.azure.net";
            var keyName = "mypemrsakey";
            var hsmEncryptUri = $"{keyVaultUrl}/keys/{keyName}/encrypt";
            HttpRequestMessage encRequest = new HttpRequestMessage(HttpMethod.Post, hsmEncryptUri);
            /*
                {
                "alg": "RSA1_5",
                "value": "5ka5IVsnGrzufA"
                }
            */
            encRequest.Content = new StringContent(@"{""alg"":""RSA1_5"",""value"":""abcdef""}",
                                    Encoding.UTF8, 
                                    "application/json");//CONTENT-TYPE header
            var task = client.SendAsync(encRequest);
            var response = await task;
            Console.WriteLine($" status = {response.StatusCode}");
            Console.WriteLine($" header --\n {response.Headers.ToString()} \n--");
            string result = response.Content.ReadAsStringAsync().Result;
            Console.WriteLine($"\n--encryption result--\n {result} \n--");

            Console.WriteLine("\n----\nTest Decryption---\n");
            var hsmDecryptUri = $"{keyVaultUrl}/keys/{keyName}/decrypt";
            HttpRequestMessage decRequest = new HttpRequestMessage(HttpMethod.Post, hsmDecryptUri);
            decRequest.Content = new StringContent("{\"alg\":\"RSA1_5\",\"value\":\"QKSjL7rXJCdhLCDqej1R_01BBFTFYedDmka1GnNoV4XC91rCQG7t58wBMRM3czvUaTbmA6aNXpKh7t_kk4a4WMK_OYhpjhqf4W8KmPuDJstWGq1CQCqDHHHczS-wcMkSlMVfu36mEC3IUJPIs_q-Zk_AED7hIAjdP8eauvWGeCAB9FB_7jPWNGKZTFMrjmD-kmlrSxCyOXSGuOmSHnz2H8nU8GEu8yO1JhSouNB6vP04MXcOEItoflZFpjSD3BARdx_Ty96qgb6PNQnfFH4xOv7tt_yYX0n0xCv6ATS8AEPDKS8_AGmBHoqBfN6FaasWwEG1cnK-VQqaXRi7YaNL3A\"}",
                                    Encoding.UTF8, 
                                    "application/json");//CONTENT-TYPE header
            task = client.SendAsync(decRequest);
            response = await task;
            result = response.Content.ReadAsStringAsync().Result;
            Console.WriteLine($" status = {response.StatusCode}");
            Console.WriteLine($" header --\n {response.Headers.ToString()} \n--");
            result = response.Content.ReadAsStringAsync().Result;
            Console.WriteLine($"\n--decryption result--\n {result} \n--");
         }
    }
}
