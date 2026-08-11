# Alertmanager Configuration & SMTP Integration

## 1. Overview

This document describes how Alertmanager was configured for the Enterprise Platform monitoring stack, how SMTP credentials are integrated securely, the problems encountered during implementation, and how those problems were resolved.

The implementation uses:

* Prometheus
* Alertmanager
* Grafana
* Helm
* Argo CD
* External Secrets Operator
* AWS Secrets Manager
* Kubernetes Secrets
* SMTP for email notifications

The design intentionally keeps SMTP credentials outside Git.

---

# 2. Target Architecture

The final secret flow is:

```text
                         AWS Secrets Manager
                                |
                                |
              enterprise-platform/dev/alertmanager
                                |
                                | ExternalSecret
                                v
                    External Secrets Operator
                                |
                                v
                     Kubernetes Secret
                      alertmanager-secret
                                |
                +---------------+---------------+
                |               |               |
           smtp-host       smtp-username    smtp-password
           smtp-port       smtp-from        smtp-to
                                |
                                v
                         Alertmanager
                                |
                                v
                           SMTP Relay
                                |
                                v
                        Alert Recipient
```

Terraform creates the AWS Secrets Manager secret containers.

External Secrets Operator retrieves the values and creates the Kubernetes Secret.

Alertmanager consumes the Kubernetes Secret for its SMTP password and uses the configured SMTP connection to send notifications.

---

# 3. AWS Secrets Manager Design

Terraform creates three secrets for the development environment:

```text
enterprise-platform/dev/auth-service
enterprise-platform/dev/grafana/admin
enterprise-platform/dev/alertmanager
```

The Alertmanager SMTP configuration belongs inside:

```text
enterprise-platform/dev/alertmanager
```

We deliberately did not create a separate secret for every SMTP property.

The Alertmanager secret contains:

```json
{
  "smtp-host": "...",
  "smtp-port": "...",
  "smtp-username": "...",
  "smtp-password": "...",
  "smtp-from": "...",
  "smtp-to": "..."
}
```

The repository's `secrets.json` maps the Terraform resource to the AWS secret name.

---

# 4. Why There Are Two Bootstrap Files

The infrastructure repository contains:

```text
environments/dev/bootstrap-secrets.template.sh
environments/dev/bootstrap-secrets.sh
```

The template is intentionally generic.

It can safely be committed to Git because it contains placeholders rather than real credentials.

Example:

```bash
aws secretsmanager put-secret-value \
  --secret-id ${PROJECT}/${ENVIRONMENT}/alertmanager \
  --secret-string '{
    "smtp-host":"CHANGE_ME",
    "smtp-port":"587",
    "smtp-username":"CHANGE_ME",
    "smtp-password":"CHANGE_ME",
    "smtp-from":"CHANGE_ME",
    "smtp-to":"CHANGE_ME"
}'
```

The environment-specific file:

```text
bootstrap-secrets.sh
```

contains the actual development values.

This file is excluded from Git through `.gitignore`.

The repository already documents using the bootstrap script to populate development secrets.

---

# 5. SMTP Configuration

Alertmanager requires an SMTP relay to send email notifications.

The configuration requires:

```text
SMTP host
SMTP port
SMTP username
SMTP password
SMTP sender
SMTP recipient
```

These values have different purposes.

## smtp-host

The hostname of the SMTP provider.

Example:

```text
smtp-relay.brevo.com
```

or another SMTP provider's relay hostname.

## smtp-port

The SMTP submission port.

A common choice is:

```text
587
```

Port 587 is commonly used for authenticated SMTP submission with TLS.

## smtp-username

The SMTP login supplied by the SMTP provider.

This is not necessarily the same as the email address shown in the `from` field.

For example, a provider may issue a dedicated SMTP login.

## smtp-password

The SMTP authentication secret.

This must not be stored in Git.

For providers such as Brevo, this is an SMTP key rather than the account password or an API key.

## smtp-from

The sender address displayed on the email.

Example:

```text
alerts@example.com
```

The sender normally needs to be configured or verified with the SMTP provider.

## smtp-to

The address that receives Alertmanager notifications.

Example:

```text
platform@example.com
```

For development this can simply be the engineer's personal email address.

---

# 6. Alertmanager Configuration

The Alertmanager configuration is stored in:

```text
charts/monitoring-assets/alertmanager/config.yaml
```

The configuration defines:

* global Alertmanager settings
* notification routes
* receivers
* email configuration
* inhibition rules
* email templates

The configuration routes alerts based on severity.

Current routing behavior:

```text
critical → platform-email
warning  → platform-email
info     → default
```

This means critical and warning alerts are sent through the configured email receiver.

---

# 7. Alertmanager Email Receiver

The email receiver uses the SMTP configuration.

Conceptually:

```yaml
receivers:

  - name: default

  - name: platform-email

    email_configs:

      - to: "..."

        from: "..."

        smarthost: "...:587"

        auth_username: "..."

        auth_password_file: "/etc/alertmanager/secrets/alertmanager-secret/smtp-password"

        require_tls: true

        send_resolved: true
```

The password is intentionally referenced as a file:

```text
/etc/alertmanager/secrets/alertmanager-secret/smtp-password
```

rather than placing the password directly inside the Alertmanager configuration.

---

# 8. External Secrets Operator

The ExternalSecret resource is located at:

```text
charts/external-secrets/templates/alertmanager-secret.yaml
```

It maps six AWS Secrets Manager properties into the Kubernetes Secret:

```text
smtp-host
smtp-port
smtp-username
smtp-password
smtp-from
smtp-to
```

The important mapping is:

```yaml
- secretKey: smtp-password
  remoteRef:
    key: enterprise-platform/dev/alertmanager
    property: smtp-password
```

The same pattern is used for the other five properties.

The Kubernetes Secret created by External Secrets is:

```text
alertmanager-secret
```

in the:

```text
monitoring
```

namespace.

---

# 9. Alertmanager Configuration Secret

The monitoring-assets Helm chart creates:

```text
alertmanager-config
```

This Secret contains:

```text
alertmanager.yaml
```

The chart renders the configuration from:

```text
alertmanager/config.yaml
```

using Helm's `tpl` functionality.

This allows environment-specific Helm values to be inserted into the Alertmanager configuration during rendering.

---

# 10. Alertmanager Templates

Custom email templates are stored under:

```text
charts/monitoring-assets/alertmanager/templates/
```

The current template includes:

```text
email.tmpl
```

The template defines:

```text
email.subject
email.body
```

The subject contains the alert status and alert name.

The body includes information such as:

```text
Alert Name
Status
Severity
Environment
```

The template is exposed to Alertmanager through the:

```text
alertmanager-templates
```

ConfigMap.

---

# 11. ConfigMap Mount

Alertmanager mounts the ConfigMap under:

```text
/etc/alertmanager/configmaps/alertmanager-templates/
```

The Alertmanager configuration therefore references:

```yaml
templates:
  - "/etc/alertmanager/configmaps/alertmanager-templates/*.tmpl"
```

This allows Alertmanager to resolve:

```text
email.subject
email.body
```

at runtime.

---

# 12. Problem Encountered: Template Functions Were Not Being Resolved

Initially the Alertmanager configuration contained:

```yaml
{{ .Values.alertmanager.smtp.to }}
{{ .Values.alertmanager.smtp.from }}
{{ .Values.alertmanager.smtp.host }}
```

but the chart was reading `config.yaml` using `.Files.Get`.

This caused Helm to treat the file as plain file content instead of evaluating the embedded Helm expressions.

The solution was to use:

```gotemplate
tpl (.Files.Get "alertmanager/config.yaml") .
```

instead of only:

```gotemplate
.Files.Get "alertmanager/config.yaml"
```

This allowed the Alertmanager configuration to consume values from `values.yaml`.

---

# 13. Problem Encountered: Missing SMTP Values

At one point Helm produced:

```text
nil pointer evaluating interface {}.smtp
```

The problem was that:

```text
.Values.alertmanager.smtp
```

did not exist in the chart values being used during rendering.

The SMTP configuration was added to:

```text
charts/monitoring-assets/values.yaml
```

with the structure:

```yaml
alertmanager:
  smtp:
    host: ...
    port: ...
    username: ...
    from: ...
    to: ...
```

After that change:

```bash
helm lint charts/monitoring-assets
```

passed successfully.

---

# 14. Problem Encountered: Email Template Not Defined

Helm initially reported:

```text
template "email.subject" not defined
```

The reason was that Alertmanager's configuration referenced:

```gotemplate
{{ template "email.subject" . }}
```

before the corresponding template was available to the rendered chart.

The solution was to create:

```text
alertmanager/templates/email.tmpl
```

and define:

```gotemplate
{{ define "email.subject" }}
[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}
{{ end }}
```

and:

```gotemplate
{{ define "email.body" }}
...
{{ end }}
```

The template is then placed in the ConfigMap mounted into Alertmanager.

---

# 15. Problem Encountered: ConfigMap Mount Path

The initial configuration used:

```text
/etc/alertmanager/templates/*.tmpl
```

However, the kube-prometheus-stack configuration mounts explicitly configured ConfigMaps under:

```text
/etc/alertmanager/configmaps/
```

The final configuration therefore uses:

```text
/etc/alertmanager/configmaps/alertmanager-templates/*.tmpl
```

This was verified against the kube-prometheus-stack chart configuration.

---

# 16. Problem Encountered: ExternalSecret YAML Indentation

When `smtp-from` and `smtp-to` were added to the ExternalSecret, Helm initially failed with:

```text
yaml: line 51: did not find expected key
```

The problem was indentation.

Incorrect:

```yaml
- secretKey: smtp-from
remoteRef:
```

Correct:

```yaml
- secretKey: smtp-from
  remoteRef:
    key: ...
    property: smtp-from
```

After correcting the indentation, Helm successfully rendered all six properties.

Validation confirmed:

```text
smtp-host
smtp-port
smtp-username
smtp-password
smtp-from
smtp-to
```

---

# 17. Validation Commands

Before deployment, validate the monitoring-assets chart:

```bash
helm lint charts/monitoring-assets
```

Render it:

```bash
helm template charts/monitoring-assets > rendered.yaml
```

Inspect the Alertmanager configuration:

```bash
grep -n -A75 "name: alertmanager-config" rendered.yaml
```

Inspect the email receiver:

```bash
grep -n -A20 "email_configs:" rendered.yaml
```

Inspect the email templates:

```bash
grep -n -A25 "name: alertmanager-templates" rendered.yaml
```

Validate External Secrets:

```bash
helm lint charts/external-secrets
```

Render:

```bash
helm template charts/external-secrets > external-secrets-rendered.yaml
```

Verify the six Alertmanager properties:

```bash
grep -n "secretKey:" external-secrets-rendered.yaml
```

Expected:

```text
smtp-host
smtp-port
smtp-username
smtp-password
smtp-from
smtp-to
```

---

# 18. Security Rules

Never commit:

```text
SMTP password
SMTP API key
SMTP secret
AWS secret values
```

The generic template may be committed:

```text
bootstrap-secrets.template.sh
```

The real environment-specific file must remain ignored:

```text
bootstrap-secrets.sh
```

AWS Secrets Manager is the source of truth for the runtime SMTP secret.

External Secrets Operator is responsible for transferring the required properties into Kubernetes.

---

# 19. Recommended Free SMTP Provider for Development

For this project, Brevo is a good option for development and low-volume platform alerts.

Brevo currently provides a free plan with 300 email sends per day.

Brevo also provides SMTP relay credentials and allows SMTP keys to be generated from:

```text
Settings
→ SMTP & API
→ SMTP
→ Generate a new SMTP key
```

The SMTP key should be treated as a password and stored securely. Brevo explicitly states that the SMTP key, rather than an API key, should be used for SMTP relay authentication.

Brevo's SMTP relay hostname is:

```text
smtp-relay.brevo.com
```

and its documented SMTP ports include:

```text
587
2525
465
```

with port 465 requiring SSL/TLS.

---

# 20. How to Create the SMTP Credentials

Create a free Brevo account.

Then:

```text
Brevo
  ↓
Settings
  ↓
SMTP & API
  ↓
SMTP
  ↓
Generate a new SMTP key
```

Give the key a descriptive name, for example:

```text
enterprise-platform-alertmanager-dev
```

Brevo recommends storing the generated key securely because the full key is shown only when it is generated.

You will then have:

```text
SMTP Host:
smtp-relay.brevo.com

SMTP Port:
587

SMTP Username:
Your Brevo SMTP login

SMTP Password:
Your generated SMTP key
```

You also need a sender address configured/verified in Brevo.

The recipient can be your own email address for development.

Brevo requires the From address to be a valid/verified sender. You create it under Settings → Senders, Domains, IPs → Senders → Add a sender. Brevo then verifies the address by sending a verification code unless you've authenticated the domain.

Create the sender

In Brevo go to:

Settings → You would see Senders, Domains, Dedicated IPs    

Slect : → Senders → Add a sender

Then use something like:

Field	       What to enter

From name	  Enterprise Platform Alerts
From email	  alerts@YOURDOMAIN.com

For example, if your authenticated domain is mycompany.com:

From name:  Enterprise Platform Alerts
From email: alerts@mycompany.com

---

# 21. Example Development Configuration

Do not commit real values.

The local development secret could conceptually look like:

```json
{
  "smtp-host": "smtp-relay.brevo.com",
  "smtp-port": "587",
  "smtp-username": "YOUR_BREVO_SMTP_LOGIN",
  "smtp-password": "YOUR_BREVO_SMTP_KEY",
  "smtp-from": "YOUR_VERIFIED_SENDER",
  "smtp-to": "YOUR_TEST_RECIPIENT"
}
```

For example:

```text
smtp-host     → smtp-relay.brevo.com
smtp-port     → 587
smtp-username → Brevo SMTP login
smtp-password → generated SMTP key
smtp-from     → verified sender
smtp-to       → your email address
```

---

# 22. Testing Strategy

After the infrastructure has been recreated:

```text
AWS Secrets Manager
        ↓
External Secrets Operator
        ↓
alertmanager-secret
        ↓
Alertmanager
        ↓
Prometheus alert
        ↓
platform-email receiver
        ↓
SMTP relay
        ↓
test recipient
```

First verify the Kubernetes Secret:

```bash
kubectl get secret alertmanager-secret -n monitoring
```

Then inspect its keys without printing the secret values:

```bash
kubectl get secret alertmanager-secret \
  -n monitoring \
  -o jsonpath='{.data}' | jq 'keys'
```

Verify Alertmanager:

```bash
kubectl get pods -n monitoring
```

Check Alertmanager logs:

```bash
kubectl logs -n monitoring <alertmanager-pod>
```

Finally trigger a controlled test alert and confirm that the notification reaches the configured recipient.

---

# 23. Final Design Principle

The most important design decision is:

```text
Git
 ↓
configuration + templates only

AWS Secrets Manager
 ↓
actual credentials

External Secrets Operator
 ↓
Kubernetes Secret

Alertmanager
 ↓
SMTP notification
```

This keeps credentials out of Git while allowing the monitoring configuration to remain fully GitOps-managed.

The SMTP provider can be replaced later without redesigning the Kubernetes architecture.

Only the values in AWS Secrets Manager need to change:

```text
smtp-host
smtp-port
smtp-username
smtp-password
smtp-from
smtp-to
```

-----------------------------------------------------------------------------
The Alertmanager and External Secrets architecture remains unchanged.
-----------------------------------------------------------------------------


                         AWS
                          │
                ┌─────────▼──────────┐
                │ Secrets Manager    │
                │                    │
                │ enterprise-platform│
                │ /dev/alertmanager  │
                └─────────┬──────────┘
                          │
                          ▼
                External Secrets Operator
                          │
                          ▼
                ┌─────────────────────┐
                │ alertmanager-secret │
                │     Kubernetes      │
                └─────────┬───────────┘
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
      Environment vars          smtp-password
       SMTP_HOST                mounted secret
       SMTP_PORT
       SMTP_USERNAME
       SMTP_FROM
       SMTP_TO
             │                         │
             └────────────┬────────────┘
                          ▼
                  ┌──────────────┐
                  │ Alertmanager │
                  │              │
                  │ config.expand│
                  │ -env=true    │
                  └──────┬───────┘
                         │
                         ▼
                  Brevo SMTP :587
                         │
                         ▼
                    Your email