using System;

namespace vm_identity_console_app
{
    public class AzureJwt
    {
        public string access_token { get; set; }
        public string client_id { get; set; }
        public string expires_in { get; set; }
        public string expires_on { get; set; }
        public string ext_expires_in { get; set; }
        public string not_before { get; set; }
        public string resource { get; set; }
        public string token_type { get; set; }
    }
}