Alertmanager Configuration, SMTP Integration & Troubleshooting
1. Overview

This document describes the implementation of Alertmanager email notifications for the Enterprise Platform monitoring stack.

The implementation integrates:

Prometheus
Alertmanager
Grafana
Helm
Argo CD
External Secrets Operator
AWS Secrets Manager
Kubernetes Secrets
Brevo SMTP
Custom Alertmanager email templates

The design follows GitOps principles:

Git
 │
 ├── Alertmanager configuration
 ├── Helm values
 ├── Alertmanager email templates
 └── Kubernetes manifests
        │
        ▼
      Argo CD
        │
        ▼
    Kubernetes

Sensitive SMTP credentials are not stored in Git.

Instead:

AWS Secrets Manager
        │
        ▼
External Secrets Operator
        │
        ▼
Kubernetes Secret
        │
        ▼
Alertmanager
        │
        ▼
Brevo SMTP
        │
        ▼
Email recipient

The final implementation was tested end-to-end and successfully delivered Alertmanager emails through Brevo to Yahoo Mail.

2. Final Architecture

The final architecture consists of two separate configuration paths.

Configuration

Non-sensitive configuration is managed through Git:

GitHub
   │
   ▼
enterprise-platform-gitops
   │
   ▼
Argo CD
   │
   ▼
monitoring-assets Helm chart
   │
   ├── Alertmanager configuration
   ├── SMTP host
   ├── SMTP port
   ├── SMTP username
   ├── SMTP from
   ├── SMTP recipient
   └── email.tmpl
Secret

The SMTP password is managed separately:

AWS Secrets Manager
        │
        │
        ▼
External Secrets Operator
        │
        ▼
Kubernetes Secret
alertmanager-secret
        │
        ▼
/etc/alertmanager/secrets/alertmanager-secret/smtp-password
        │
        ▼
Alertmanager
Notification flow
Prometheus
    │
    │ Alert fires
    ▼
Alertmanager
    │
    │ Route based on severity
    ▼
platform-email
    │
    │ SMTP :587
    ▼
Brevo
    │
    ▼
Yahoo Mail
3. Repository Structure

The relevant GitOps structure is:

enterprise-platform-gitops/
│
├── charts/
│   │
│   ├── monitoring/
│   │
│   ├── monitoring-assets/
│   │   │
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   │
│   │   ├── alertmanager/
│   │   │   ├── config.yaml
│   │   │   │
│   │   │   └── templates/
│   │   │       └── email.tmpl
│   │   │
│   │   └── templates/
│   │       ├── alertmanager-config-secret.yaml
│   │       └── alertmanager-templates-configmap.yaml
│   │
│   └── external-secrets/
│
└── ...

The important files are:

charts/monitoring-assets/values.yaml
charts/monitoring-assets/alertmanager/config.yaml
charts/monitoring-assets/alertmanager/templates/email.tmpl
charts/monitoring-assets/templates/alertmanager-config-secret.yaml

The ExternalSecret configuration is managed separately under:

charts/external-secrets/
4. Alertmanager SMTP Configuration

The SMTP configuration is defined under:

charts/monitoring-assets/values.yaml

The structure is:

alertmanager:
  smtp:
    host: smtp-relay.brevo.com
    port: 587
    username: YOUR_SMTP_USERNAME
    from: alerts@example.com
    to: recipient@example.com
Important

The SMTP password is not placed in values.yaml.

The password remains in AWS Secrets Manager and is synchronized into Kubernetes by External Secrets Operator.

5. SMTP Configuration Values

The SMTP configuration contains:

Value	Purpose
host	SMTP relay hostname
port	SMTP submission port
username	SMTP authentication username
from	Email sender
to	Alert recipient
password	SMTP authentication secret

The implementation uses:

SMTP host: smtp-relay.brevo.com
SMTP port: 587
TLS: enabled

The SMTP password is provided to Alertmanager through a mounted Kubernetes Secret.

6. AWS Secrets Manager

The Alertmanager secret is stored in AWS Secrets Manager under:

enterprise-platform/dev/alertmanager

The secret contains:

{
  "smtp-host": "...",
  "smtp-port": "...",
  "smtp-username": "...",
  "smtp-password": "...",
  "smtp-from": "...",
  "smtp-to": "..."
}
Security principle

Only the password needs to remain strictly secret at runtime.

However, the entire SMTP configuration should be treated as environment configuration and should not expose unnecessary credentials in Git.

Never commit:

SMTP password
SMTP key
AWS credentials
API keys
private credentials
7. External Secrets Operator

External Secrets Operator retrieves the values from AWS Secrets Manager and creates:

Secret:
alertmanager-secret

Namespace:
monitoring

The secret contains keys such as:

smtp-host
smtp-port
smtp-username
smtp-password
smtp-from
smtp-to

The most important key for Alertmanager authentication is:

smtp-password

Alertmanager consumes it from:

/etc/alertmanager/secrets/alertmanager-secret/smtp-password
8. Alertmanager Configuration

The main Alertmanager configuration is:

charts/monitoring-assets/alertmanager/config.yaml

It defines:

global configuration
routing
receivers
email configuration
inhibition rules

The current routing strategy is:

critical → platform-email
warning  → platform-email
info     → default

Therefore:

Critical alerts → email
Warning alerts  → email
Info alerts     → default receiver
9. The platform-email Receiver

The receiver uses:

receivers:

  - name: default

  - name: platform-email
    email_configs:
      - to: "{{ .Values.alertmanager.smtp.to }}"
        from: "{{ .Values.alertmanager.smtp.from }}"
        smarthost: "{{ .Values.alertmanager.smtp.host }}:{{ .Values.alertmanager.smtp.port }}"
        auth_username: "{{ .Values.alertmanager.smtp.username }}"
        auth_password_file: "/etc/alertmanager/secrets/alertmanager-secret/smtp-password"
        require_tls: true
        send_resolved: true

The important security decision is:

auth_password_file:
  /etc/alertmanager/secrets/alertmanager-secret/smtp-password

rather than:

auth_password: "actual-password"
10. Why tpl Was Required

One of the major problems encountered was that alertmanager/config.yaml was loaded using:

.Files.Get

The file contained Helm expressions such as:

{{ .Values.alertmanager.smtp.to }}

However, .Files.Get reads the file as content and does not automatically evaluate those Helm expressions.

The solution was:

{{ tpl (.Files.Get "alertmanager/config.yaml") . | indent 4 }}

This is used in:

charts/monitoring-assets/templates/alertmanager-config-secret.yaml

The important distinction is:

.Files.Get

means:

Read this file.

Whereas:

tpl (.Files.Get ...) .

means:

Read this file and evaluate the Helm templates inside it.

This allowed:

.Values.alertmanager.smtp.*

to be rendered correctly.

11. Helm Values Structure

The values must have the correct hierarchy.

Correct:

alertmanager:
  smtp:
    host: smtp-relay.brevo.com
    port: 587
    username: YOUR_USERNAME
    from: alerts@example.com
    to: recipient@example.com

A missing hierarchy can result in errors such as:

nil pointer evaluating interface {}.smtp

Therefore, when changing Alertmanager values, verify the indentation carefully.

12. Custom Email Template

The custom template is:

charts/monitoring-assets/alertmanager/templates/email.tmpl

It defines:

email.subject
email.body

The final subject logic is:

{{ define "email.subject" }}
{{ if eq .Status "firing" -}}
🚨 [{{ .CommonLabels.severity | toUpper }}] {{ .CommonLabels.alertname }} — {{ .CommonLabels.environment }} / {{ .CommonLabels.namespace }}
{{- else -}}
✅ [{{ .CommonLabels.severity | toUpper }}] {{ .CommonLabels.alertname }} — {{ .CommonLabels.environment }} / {{ .CommonLabels.namespace }}
{{- end }}
{{ end }}

This produces:

Firing
🚨 [WARNING] AlertmanagerSubjectTest — dev / monitoring
Resolved
✅ [WARNING] AlertmanagerSubjectTest — dev / monitoring

This makes the notification immediately understandable from the email subject.

13. Email Body

The body includes:

ENTERPRISE PLATFORM - ALERT NOTIFICATION

Alert
Status
Severity

Environment
Cluster
Namespace
Team

Alert Details
Summary
Description

Alert Instance
Started
Resolved
Labels

Runbook

Alertmanager

For a firing alert:

ALERT FIRING

is displayed.

For a resolved alert:

ALERT RESOLVED

is displayed.

14. Critical Template Problem We Encountered

An important Alertmanager template issue occurred with:

{{ .StartsAt }}

Initially, .StartsAt was referenced directly from the top-level template context.

Alertmanager produced:

can't evaluate field StartsAt in type *template.Data

The problem was that .StartsAt belongs to an individual alert object, not the top-level Alertmanager template data.

The solution was to iterate through the alerts:

{{ range .Alerts }}

Started:
{{ .StartsAt }}

{{ end }}

This changed the template context from:

template.Data

to:

individual alert

where:

.StartsAt
.EndsAt
.Labels

are available.

This is an important Alertmanager template rule.

15. Correct Alertmanager Template Scope

Top-level properties include things such as:

.Status
.CommonLabels
.CommonAnnotations

Individual alert properties include:

.StartsAt
.EndsAt
.Labels
.Annotations

Therefore:

{{ .CommonLabels.alertname }}

is valid at the top level.

But:

{{ .StartsAt }}

must be used inside:

{{ range .Alerts }}

For example:

{{ range .Alerts }}

Started:
{{ .StartsAt }}

{{ if not .EndsAt.IsZero }}
Resolved:
{{ .EndsAt }}
{{ end }}

{{ end }}
16. Alertmanager Template ConfigMap

The template is exposed through:

alertmanager-templates

ConfigMap.

The template is mounted into Alertmanager at:

/etc/alertmanager/configmaps/alertmanager-templates/

The Alertmanager configuration references:

templates:
  - "/etc/alertmanager/configmaps/alertmanager-templates/*.tmpl"

This mount path was important because the initial assumption about the template path was incorrect.

17. Verifying the Template in Kubernetes

Check the ConfigMap:

kubectl get configmap alertmanager-templates \
  -n monitoring \
  -o jsonpath='{.data.email\.tmpl}'

You should see:

define "email.subject"

and:

define "email.body"

You can also inspect the actual file mounted inside the Alertmanager container:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  cat /etc/alertmanager/configmaps/alertmanager-templates/email.tmpl
18. Important Windows Git Bash Issue

Because the environment is Windows Git Bash, commands containing Linux paths can be modified by MSYS path conversion.

For example:

kubectl exec ... cat /etc/alertmanager/...

can incorrectly become something resembling:

C:/Program Files/Git/etc/alertmanager/...

This produced errors such as:

cat: can't open 'C:/Program Files/Git/etc/...'

The solution is:

MSYS_NO_PATHCONV=1

For example:

MSYS_NO_PATHCONV=1 kubectl exec ...

This should be used when executing commands that contain Linux container paths from Git Bash on Windows.

19. Actual Alertmanager StatefulSet Name

The Alertmanager StatefulSet is:

alertmanager-prometheus-stack-kube-prom-alertmanager

The pod is:

alertmanager-prometheus-stack-kube-prom-alertmanager-0

This is important because the Prometheus stack name is part of the generated resource name.

For example, this is incorrect:

kubectl rollout restart statefulset \
  prometheus-stack-kube-prom-alertmanager \
  -n monitoring

The correct StatefulSet is:

kubectl rollout restart statefulset \
  alertmanager-prometheus-stack-kube-prom-alertmanager \
  -n monitoring

Verify with:

kubectl get statefulsets -n monitoring
20. Do You Need to Restart Alertmanager?

Normally, do not immediately restart Alertmanager after every configuration change.

First verify whether the mounted ConfigMap/configuration has already been updated.

Check:

kubectl get configmap alertmanager-templates \
  -n monitoring \
  -o jsonpath='{.data.email\.tmpl}'

Then check the mounted file:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  cat /etc/alertmanager/configmaps/alertmanager-templates/email.tmpl

If the new template is already present, Alertmanager has access to it.

A restart can still be used when necessary:

kubectl rollout restart statefulset \
  alertmanager-prometheus-stack-kube-prom-alertmanager \
  -n monitoring

Then:

kubectl get pods -n monitoring | grep alertmanager

Wait until:

2/2 Running
21. Argo CD Synchronization

The monitoring resources are managed through Argo CD.

Check:

kubectl get applications -n argocd

The relevant applications include:

monitoring-assets
monitoring-alerts
prometheus-stack

For changes to:

charts/monitoring-assets/

the primary application to synchronize is:

monitoring-assets

After pushing Git changes:

git add .
git commit -m "..."
git push origin main

verify:

kubectl get applications -n argocd

Expected:

monitoring-assets   Synced   Healthy

If it remains OutOfSync, synchronize monitoring-assets in Argo CD.

22. Helm Validation

Before pushing changes:

helm lint charts/monitoring-assets

Expected:

1 chart(s) linted, 0 chart(s) failed

Render:

helm template charts/monitoring-assets \
  > /tmp/monitoring-assets-rendered.yaml

Inspect the receiver:

grep -n -A20 "platform-email" \
  /tmp/monitoring-assets-rendered.yaml

Inspect the template:

grep -n -A80 "email.tmpl:" \
  /tmp/monitoring-assets-rendered.yaml

Verify the template contains:

.StartsAt

inside:

range .Alerts
23. Verify the Rendered SMTP Configuration

Run:

grep -n -A15 "name: platform-email" \
  /tmp/monitoring-assets-rendered.yaml

Expected structure:

- name: platform-email
  email_configs:
    - to: "..."
      from: "..."
      smarthost: "smtp-relay.brevo.com:587"
      auth_username: "..."
      auth_password_file: "/etc/alertmanager/secrets/alertmanager-secret/smtp-password"
      require_tls: true
      send_resolved: true

Do not print or commit the actual SMTP password.

24. Verify Alertmanager Configuration in the Pod

Run:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  grep -n -A15 -B5 "platform-email" \
  /etc/alertmanager/config_out/alertmanager.env.yaml

You should see:

receiver: platform-email

and:

smtp-relay.brevo.com:587

and:

auth_password_file:

and:

templates:
- /etc/alertmanager/configmaps/alertmanager-templates/*.tmpl
25. Verify Alertmanager Health

Check the pod:

kubectl get pods -n monitoring | grep alertmanager

Expected:

alertmanager-prometheus-stack-kube-prom-alertmanager-0
2/2 Running

Check the Alertmanager resource:

kubectl get alertmanager -n monitoring

Expected:

READY       1
RECONCILED  True
AVAILABLE   True
26. Check Alertmanager Logs

Use:

kubectl logs -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager --since=10m

Filter for notification problems:

kubectl logs -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager --since=10m |
  grep -iE "notify|error|smtp|email|platform-email"

Successful configuration loading looks like:

Loading configuration file
Completed loading of configuration file

A previous template problem produced:

can't evaluate field StartsAt in type *template.Data

If that appears again, inspect email.tmpl and verify .StartsAt is inside:

{{ range .Alerts }}
27. Checking Alertmanager Routes

Use:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool config routes test \
  --alertmanager.url=http://localhost:9093 \
  severity=warning \
  namespace=monitoring \
  team=platform \
  alertname=TestAlert

For a warning alert, the expected receiver is:

platform-email

This is an important troubleshooting step because an alert can exist in Alertmanager but still not be routed to email.

28. Firing a Manual Test Alert

The most reliable method used during testing was amtool.

Use:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool alert add AlertmanagerSubjectTest \
  'severity=warning' \
  'namespace=monitoring' \
  'team=platform' \
  'environment=dev' \
  --annotation='summary=Subject Test' \
  --annotation='description=Testing dynamic firing and resolved subjects' \
  --alertmanager.url=http://localhost:9093
Important Git Bash note

Always use:

MSYS_NO_PATHCONV=1

when necessary on Windows Git Bash.

29. amtool Parser Warning

During testing, commands containing spaces in annotations produced warnings such as:

Alertmanager is moving to a new parser for labels and matchers

For example:

summary=Enterprise Platform Alertmanager Test

could generate parser warnings.

This did not mean SMTP was broken.

The alert was still created successfully.

The warning comes from amtool parsing the matcher-style input.

The safer approach is to quote the annotation:

--annotation='summary=Enterprise Platform Alertmanager Test'

and:

--annotation='description=Testing Alertmanager email delivery'

The warning can still appear depending on the Alertmanager/amtool version, but it does not necessarily indicate notification failure.

30. Verify the Test Alert

Query the alert:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool alert query \
  'alertname="AlertmanagerSubjectTest"' \
  --alertmanager.url=http://localhost:9093

Expected:

AlertmanagerSubjectTest

with:

active
31. Inspect Alert Details

Use:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool alert query \
  'alertname="AlertmanagerSubjectTest"' \
  --alertmanager.url=http://localhost:9093 \
  -o extended

This displays:

Labels
Annotations
Starts At
Ends At
State

This is useful for confirming that:

severity
namespace
team
environment
summary
description

were actually attached to the alert.

32. Verify Email Delivery Through Metrics

Alertmanager exposes notification metrics.

Check successful email notification attempts:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  wget -qO- http://localhost:9093/metrics |
  grep 'alertmanager_notifications_total{integration="email"}'

Example:

alertmanager_notifications_total{integration="email"} 8

The exact number will change as more notifications are sent.

33. Check for Failed Email Notifications

Run:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  wget -qO- http://localhost:9093/metrics |
  grep 'alertmanager_notification_requests_failed_total{integration="email"}'

The desired result is:

alertmanager_notification_requests_failed_total{integration="email"} 0

This was successfully achieved during testing.

This is one of the strongest indicators that the SMTP delivery mechanism itself is working.

34. Troubleshooting: Email Not Received

If an alert exists but no email arrives, troubleshoot in this order.

Step 1 — Is the alert active?
amtool alert query ...
Step 2 — Is it routed to email?
amtool config routes test ...

Expected:

platform-email
Step 3 — Check Alertmanager logs
kubectl logs ...

Search for:

notify
error
smtp
email
platform-email
Step 4 — Check notification metrics
alertmanager_notifications_total

and:

alertmanager_notification_requests_failed_total
Step 5 — Check the recipient's spam folder

During testing, Yahoo Mail placed several Alertmanager emails in Spam.

This does not necessarily indicate an Alertmanager or SMTP failure.

If the email exists in Spam, SMTP delivery succeeded.

35. Yahoo Mail / Spam Behavior

During testing, Alertmanager emails were successfully delivered to Yahoo Mail but some messages initially appeared in Spam.

The Yahoo message displayed:

For your security we disabled all images and links in this email.

and Yahoo's interface offered:

mark this message as not spam

This is a recipient-side email filtering issue rather than an Alertmanager SMTP failure.

If the messages repeatedly land in Spam:

Open the message.
Select Not Spam / Mark as not spam.
Add the sender to contacts if appropriate.
Verify that the sending domain/sender is properly authenticated with the SMTP provider.
For production, use a properly authenticated organizational domain.
36. Troubleshooting: Template Is Not Updated

Check the ConfigMap:

kubectl get configmap alertmanager-templates \
  -n monitoring \
  -o jsonpath='{.data.email\.tmpl}'

Then check the mounted file:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  cat /etc/alertmanager/configmaps/alertmanager-templates/email.tmpl

If the ConfigMap contains the new template but the mounted file does not, investigate the pod/mount.

If both contain the new template, the template is available to Alertmanager.

37. Troubleshooting: Template Error

If logs contain:

can't evaluate field StartsAt in type *template.Data

look for:

{{ .StartsAt }}

outside:

{{ range .Alerts }}

Correct:

{{ range .Alerts }}

Started:
{{ .StartsAt }}

{{ end }}

Incorrect:

Started:
{{ .StartsAt }}

at the top level.

38. Troubleshooting: StatefulSet Not Found

If:

kubectl rollout restart statefulset prometheus-stack-kube-prom-alertmanager

returns:

statefulsets.apps "... " not found

list the actual StatefulSets:

kubectl get statefulsets -n monitoring

The generated Alertmanager StatefulSet in this implementation is:

alertmanager-prometheus-stack-kube-prom-alertmanager
39. Troubleshooting: Argo CD OutOfSync

Check:

kubectl get applications -n argocd

Look for:

monitoring-assets

If it says:

OutOfSync

synchronize the application through Argo CD.

After synchronization:

kubectl get applications -n argocd

Expected:

monitoring-assets   Synced   Healthy
40. Troubleshooting: Helm Rendering

Always render the chart locally before pushing:

helm lint charts/monitoring-assets

then:

helm template charts/monitoring-assets \
  > /tmp/monitoring-assets-rendered.yaml

Check the SMTP receiver:

grep -n -A20 "platform-email" \
  /tmp/monitoring-assets-rendered.yaml

Check the template:

grep -n "StartsAt" \
  /tmp/monitoring-assets-rendered.yaml

Check for accidental unresolved Helm variables:

grep -n '\${SMTP_' \
  /tmp/monitoring-assets-rendered.yaml

The output should be empty if no unresolved ${SMTP_*} placeholders are being used.

41. GitOps Deployment Workflow

The normal workflow is:

1. Modify Helm configuration
        ↓
2. helm lint
        ↓
3. helm template
        ↓
4. Inspect rendered configuration
        ↓
5. git diff --check
        ↓
6. git add
        ↓
7. git commit
        ↓
8. git push
        ↓
9. Argo CD sync
        ↓
10. Verify Kubernetes resources
        ↓
11. Test Alertmanager
        ↓
12. Verify email

Example:

helm lint charts/monitoring-assets
helm template charts/monitoring-assets \
  > /tmp/monitoring-assets-rendered.yaml
git diff --check
git status

Then:

git add charts/monitoring-assets/
git commit -m "feat: update Alertmanager notifications"
git push origin main
42. Final End-to-End Verification Checklist

Before considering Alertmanager production-ready, verify:

Git
[ ] Changes committed
[ ] Changes pushed
[ ] No secrets committed
Helm
[ ] helm lint passes
[ ] helm template succeeds
[ ] SMTP configuration renders correctly
[ ] email.tmpl renders correctly
Argo CD
[ ] monitoring-assets = Synced
[ ] monitoring-assets = Healthy
Kubernetes
[ ] Alertmanager pod = Running
[ ] Alertmanager = Ready
[ ] ConfigMap exists
[ ] alertmanager-secret exists
Alertmanager
[ ] Configuration loads successfully
[ ] platform-email route works
[ ] SMTP configuration is present
[ ] Template is mounted
Email
[ ] Test firing email received
[ ] Test resolved email received
[ ] Dynamic subject works
[ ] SMTP failure metric = 0
43. Final Tested Notification Format

The final notification subject format is:

Firing
🚨 [WARNING] AlertName — dev / monitoring
Resolved
✅ [WARNING] AlertName — dev / monitoring

This gives the recipient immediate visibility into:

Status
Severity
Alert
Environment
Namespace

without opening the email.

44. Final Testing Procedure

For a quick future smoke test:

Create alert
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool alert add AlertmanagerSmokeTest \
  'severity=warning' \
  'namespace=monitoring' \
  'team=platform' \
  'environment=dev' \
  --annotation='summary=Alertmanager Smoke Test' \
  --annotation='description=Testing Alertmanager email delivery' \
  --alertmanager.url=http://localhost:9093
Verify alert
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool alert query \
  'alertname="AlertmanagerSmokeTest"' \
  --alertmanager.url=http://localhost:9093
Verify routing
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool config routes test \
  --alertmanager.url=http://localhost:9093 \
  severity=warning \
  namespace=monitoring \
  team=platform \
  alertname=AlertmanagerSmokeTest

Expected:

platform-email
Verify notification failures
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  wget -qO- http://localhost:9093/metrics |
  grep 'alertmanager_notification_requests_failed_total{integration="email"}'

Expected:

... 0
Expire the test
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-alertmanager-0 \
  -c alertmanager -- \
  amtool alert expire \
  'alertname="AlertmanagerSmokeTest"' \
  --alertmanager.url=http://localhost:9093

Important: use the actual pod name:

alertmanager-prometheus-stack-kube-prom-alertmanager-0

so the complete command should be:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring \
  alertmanager-prometheus-stack-kube-prom-alertmanager-0 \
  -c alertmanager -- \
  amtool alert expire \
  'alertname="AlertmanagerSmokeTest"' \
  --alertmanager.url=http://localhost:9093

Because:

send_resolved: true

you should receive the resolved notification.

45. Lessons Learned

Several important lessons came out of this implementation.

1. Helm .Files.Get does not automatically evaluate Helm expressions

Use:

tpl (.Files.Get "file") .

when a file contains Helm template expressions.

2. Alertmanager template context matters

Top-level:

.CommonLabels
.CommonAnnotations
.Status

Individual alert:

.StartsAt
.EndsAt
.Labels
.Annotations

Use:

range .Alerts

when accessing individual alert properties.

3. Always validate rendered Helm output

A successful:

helm lint

does not guarantee that the final rendered configuration is exactly what you expect.

Use:

helm template

and inspect the output.

4. Kubernetes generated names matter

Do not assume the StatefulSet name.

Use:

kubectl get statefulsets -n monitoring

before attempting a restart.

5. Git Bash can modify Linux paths

On Windows:

MSYS_NO_PATHCONV=1

can be necessary when using kubectl exec with container paths.

6. Alert existence does not guarantee email delivery

Always verify:

Alert exists
       ↓
Route matches
       ↓
Receiver = platform-email
       ↓
SMTP notification attempted
       ↓
No failed notification requests
       ↓
Email received
7. Email spam filtering is separate from SMTP delivery

An email appearing in Yahoo Spam does not mean Alertmanager failed.

If the message arrives in Spam, the SMTP pipeline successfully delivered it.

46. Final State

The completed architecture is:

                         GitHub
                           │
                           ▼
                    enterprise-platform
                       -gitops
                           │
                           ▼
                        Argo CD
                           │
                           ▼
                monitoring-assets Helm
                         Chart
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
      Alertmanager config          Email template
             │                           │
             │                     email.tmpl
             │                           │
             └─────────────┬─────────────┘
                           │
                           ▼
                     Alertmanager
                           │
                 ┌─────────┴─────────┐
                 │                   │
                 ▼                   ▼
          SMTP configuration    SMTP password
             from Helm          from K8s Secret
                 │                   ▲
                 │                   │
                 │            External Secrets
                 │                   ▲
                 │                   │
                 │          AWS Secrets Manager
                 │
                 ▼
             Brevo SMTP
                 │
                 ▼
             Yahoo Mail

The key security boundary is:

Git → configuration
AWS Secrets Manager → credentials
External Secrets → Kubernetes secret
Alertmanager → notification
Brevo → SMTP delivery