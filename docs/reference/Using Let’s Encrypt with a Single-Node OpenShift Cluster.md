Securing a Single-Node OpenShift (SNO) cluster with a trusted TLS certificate is straightforward, and works reliably with Let’s Encrypt. This guide explains how to request a certificate using DNS-01 validation and how to install and renew it for OpenShift’s ingress router.

Let’s Encrypt certificates are valid for 90 days, so an automated refresh mechanism is essential. The process below covers both the initial installation and the renewal workflow.

Here is a blog on the topic to supplement these notes: [click here](https://www.redhat.com/en/blog/requesting-and-installing-lets-encrypt-certificates-for-openshift-4)


---

## Why Use a Wildcard Certificate

OpenShift exposes all application routes under the `*.apps.<cluster-domain>` subdomain. Using a wildcard certificate avoids needing separate certificates for each application. For the domain:

`sno.bakerapps.net`

the appropriate wildcard is:

`*.apps.sno.bakerapps.net`

This certificate will secure all OpenShift routes, including the OAuth login pages.

---

## Requesting the Certificate with DNS-01

DNS-01 validation is the preferred method for requesting a wildcard certificate because it works regardless of firewall or router configuration.

From any Linux machine with certbot installed, run:

```bash
sudo certbot certonly --manual \
  --preferred-challenges dns \
  -d "*.apps.sno.bakerapps.net" \
  -d "api.sno.bakerapps.net"
```

Certbot will pause and ask you to create a TXT record. E.g.:

```none
$ sudo certbot certonly --manual \
  --preferred-challenges dns \
  -d "*.apps.sno.bakerapps.net" \
  -d "api.sno.bakerapps.net"
[sudo] password for bryon: 
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Requesting a certificate for *.apps.sno.bakerapps.net and api.sno.bakerapps.net

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please deploy a DNS TXT record under the name:

_acme-challenge.apps.sno.bakerapps.net.

with the following value:

zl0PSbXDPFUuQJYbaA2fjdBSPWjZTm7s7GduMtDiPyA

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

Add this TXT record at your DNS provider:

- **Name**:
    
    `_acme-challenge.apps.sno.bakerapps.net`
    
- **Value**:  
    The token provided by certbot.

Checking DNS is updated globally:

```bash
curl -s \
  "https://dns.google/resolve?name=_acme-challenge.apps.sno.bakerapps.net&type=TXT" \
  | jq .
```

If the service is hosted in AWS you can quickly check prior to it being propagated globally using Cloudflare DNS:

```bash
curl -s \
  -H "accept: application/dns-json" \
  "https://cloudflare-dns.com/dns-query?name=_acme-challenge.apps.bakerapps.net&type=TXT" \
  | jq .
```


Once the TXT record is visible, press Enter and certbot will issue the certificate. The resulting files appear in:

`/etc/letsencrypt/live/<domain>/`

The two files required by OpenShift are:

- `fullchain.pem`
    
- `privkey.pem`

## Retrieving the certificate

Once you have retrieved the certificate put it in a safe place.

```bash
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/apps.sno.bakerapps.net/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/apps.sno.bakerapps.net/privkey.pem
This certificate expires on 2026-03-06.
These files will be updated when the certificate renews.

NEXT STEPS:
- This certificate will not be renewed automatically. Autorenewal of --manual certificates requires the use of an authentication hook script (--manual-auth-hook) but one was not provided. To renew this certificate, repeat this same certbot command before the certificate's expiry date.


```

---

## Installing the Certificate in OpenShift Console

OpenShift uses the ingress controller to serve certificates for all routes. To install the new Let’s Encrypt certificate, create a secret containing the certificate and private key:

```bash
oc -n openshift-ingress create secret tls router-certs \
   --cert=fullchain.pem \
   --key=privkey.pem
```

Then configure the default ingress controller to use the secret:

```bash
oc -n openshift-ingress-operator patch ingresscontroller default \
   --type=merge \
   -p '{"spec":{"defaultCertificate":{"name":"router-certs"}}}'
```

OpenShift will automatically restart the router pods and begin serving the trusted certificate for all routes.

## Installing the Certificate in the OpenShift API 

```bash
oc -n openshift-config create secret tls api-certs \
--cert=fullchain.pem \
--key=privkey.pem
```

**WARNING**: Make sure you insert your cluster base domain or you will brick accessing the cluster via the cli.

```bash
export BASE_DOMAIN=yourcluster.example.com
oc patch apiserver cluster \
  --type=merge \
  -p '{"spec":{"servingCerts":{"namedCertificates":[{"names":["api.$BASE_DOMAIN"],"servingCertificate":{"name":"api-certs"}}]}}}'
```

### Verification

#### Check API Server Certificate:

```bash
echo | openssl s_client -servername api.$BASE_DOMAIN -connect api.$BASE_DOMAIN:6443 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

#### Check Ingress/Router Certificate (for console and apps)

```bash
echo | openssl s_client -servername console-openshift-console.apps.$BASE_DOMAIN -connect console-openshift-console.apps.$BASE_DOMAIN:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

#### Both in one command
```bash
for host in "api.$BASE_DOMAIN$:6443" "console-openshift-console.apps.$BASE_DOMAIN$:443"; do
  echo "=== Checking $host ==="
  echo | openssl s_client -servername ${host%:*} -connect $host 2>/dev/null | openssl x509 -noout -subject -issuer -dates
  echo
done
```

#### Check expiration only
```bash
echo | openssl s_client -servername api.ocpai.sandbox3279.opentlc.com -connect api.ocpai.sandbox3279.opentlc.com:6443 2>/dev/null | openssl x509 -noout -enddate
```

#### What to look for

- notAfter date should be in the future
- issuer should be Let's Encrypt
- Verify return code: 0 (ok) means the certificate chain is valid


---

## Renewing the Certificate

OpenShift does not automatically renew Let’s Encrypt certificates. A renewal mechanism must replace the secret before the certificate expires. Two approaches are recommended: external renewal automation or in-cluster automation with cert-manager.

---

### Option 1: External Automation (certbot or acme.sh)

An external host can manage renewal with a simple script. After renewal, update the OpenShift secret:

```bash
certbot renew  oc -n openshift-ingress delete secret router-certs oc \
   -n openshift-ingress create secret tls router-certs \
   --cert=/etc/letsencrypt/live/<domain>/fullchain.pem \
   --key=/etc/letsencrypt/live/<domain>/privkey.pem
```

This approach works with cron and requires only that the host can access the OpenShift API.

---

### Option 2: Using cert-manager in OpenShift

Installing cert-manager provides full automation within the cluster. With a properly configured DNS-01 `ClusterIssuer`, cert-manager:

- Requests the Let’s Encrypt certificate
    
- Stores it in a Kubernetes secret
    
- Automatically renews it before expiry
    
- Keeps the ingress router updated
    

This is the most automated approach but involves installing an additional operator on SNO.

---

## Verifying the Certificate

To confirm that the new certificate is active, use:

```bash
openssl s_client -connect console-openshift-console.apps.sno.bakerapps.net:443 \
   -servername console-openshift-console.apps.sno.bakerapps.net | \
   openssl x509 -noout -dates
```

This displays the certificate’s expiry date and confirms that the router now serves the Let’s Encrypt certificate.

---

## Summary

Using Let’s Encrypt with a Single-Node OpenShift cluster is simple, secure, and effective. The steps are:

1. Request a wildcard certificate using DNS-01.
    
2. Create an ingress TLS secret with the certificate.
    
3. Patch the default ingress controller to use the secret.
    
4. Implement a renewal method so the certificate stays valid.
    

Once configured, OpenShift will automatically serve the trusted certificate across all application routes, improving both security and user experience.

# RHPDS Configuration Notes

This example uses an example for a cluster called: `ethan-kk-poc` running in the RHPDS environment `sandbox3454.opentlc.com`
## Certbot

Run certbot
```
sudo certbot certonly --manual --preferred-challenges dns -d "*.apps.ethan-kk-poc.sandbox3454.opentlc.com"
```

```
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please deploy a DNS TXT record under the name:

_acme-challenge.apps.ethan-kk-poc.sandbox3454.opentlc.com.

with the following value:

Rgu70pLyiVoR3WpqllhiLXFL6yKN-IiyYOr4y3lFSPk

Before continuing, verify the TXT record has been deployed. Depending on the DNS
provider, this may take some time, from a few seconds to multiple minutes. You can
check if it has finished deploying with aid of online tools, such as the Google
Admin Toolbox: https://toolbox.googleapps.com/apps/dig/#TXT/_acme-challenge.apps.ethan-kk-poc.sandbox3454.opentlc.com.
Look for one or more bolded line(s) below the line ';ANSWER'. It should show the
value(s) you've just added.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

## Configure Route53
1. Within Route53, find the `hosted zone` for the OpenShift cluster. There will be two. You want the hosted zone that starts with `sandbox`.
2. Add a TXT record with a TTL of 60 seconds.
3. Test it is there:

Test it is in Route53 first:
```
$ dig NS sandbox3454.opentlc.com +short
ns-869.awsdns-44.net.
ns-1359.awsdns-41.org.
ns-161.awsdns-20.com.
ns-1836.awsdns-37.co.uk.

$ dig TXT _acme-challenge.apps.ethan-kk-poc.sandbox3454.opentlc.com @ns-869.awsdns-44.net +short
```

Wait for it to appear in Global DNS
```
while true; do   echo "[$(date)]";   dig TXT _acme-challenge.apps.ethan-kk-poc.sandbox3454.opentlc.com @8.8.8.8 +short;   echo "----";   sleep 10; done
```

## Troubleshooting "dig"

Sometimes an external DNS may be blocked, resulting in "`;; communications error to 8.8.8.8#53: timed out`." In which case use this:

```base
while true; do
  echo "[$(date)]"
  dig TXT _acme-challenge.apps.ocpai.sandbox3279.opentlc.com +short
  echo "----"
  sleep 10
done
```