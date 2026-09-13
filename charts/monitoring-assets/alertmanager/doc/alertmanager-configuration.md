Alertmanager Configuration, SMTP Integration & Troubleshooting

Overview

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

Final Architecture

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

SMTP Configuration Values

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

AWS Secrets Manager

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

name: default

name: platform-email
email_configs:

to: "{{ .Values.alertmanager.smtp.to }}"
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

Helm Values Structure

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

Custom Email Template

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

Email Body

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

Critical Template Problem We Encountered

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

Correct Alertmanager Template Scope

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

"/etc/alertmanager/configmaps/alertmanager-templates/*.tmpl"

This mount path was important because the initial assumption about the template path was incorrect.

Verifying the Template in Kubernetes

Check the ConfigMap:

kubectl get configmap alertmanager-templates 
-n monitoring 
-o jsonpath='{.data.email.tmpl}'

You should see:

define "email.subject"

and:

define "email.body"

You can also inspect the actual file mounted inside the Alertmanager container:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
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

Actual Alertmanager StatefulSet Name

The Alertmanager StatefulSet is:

alertmanager-prometheus-stack-kube-prom-alertmanager

The pod is:

alertmanager-prometheus-stack-kube-prom-alertmanager-0

This is important because the Prometheus stack name is part of the generated resource name.

For example, this is incorrect:

kubectl rollout restart statefulset 
prometheus-stack-kube-prom-alertmanager 
-n monitoring

The correct StatefulSet is:

kubectl rollout restart statefulset 
alertmanager-prometheus-stack-kube-prom-alertmanager 
-n monitoring

Verify with:

kubectl get statefulsets -n monitoring
20. Do You Need to Restart Alertmanager?

Normally, do not immediately restart Alertmanager after every configuration change.

First verify whether the mounted ConfigMap/configuration has already been updated.

Check:

kubectl get configmap alertmanager-templates 
-n monitoring 
-o jsonpath='{.data.email.tmpl}'

Then check the mounted file:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
cat /etc/alertmanager/configmaps/alertmanager-templates/email.tmpl

If the new template is already present, Alertmanager has access to it.

A restart can still be used when necessary:

kubectl rollout restart statefulset 
alertmanager-prometheus-stack-kube-prom-alertmanager 
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

Helm Validation

Before pushing changes:

helm lint charts/monitoring-assets

Expected:

1 chart(s) linted, 0 chart(s) failed

Render:

helm template charts/monitoring-assets 


/tmp/monitoring-assets-rendered.yaml

Inspect the receiver:

grep -n -A20 "platform-email" 
/tmp/monitoring-assets-rendered.yaml

Inspect the template:

grep -n -A80 "email.tmpl:" 
/tmp/monitoring-assets-rendered.yaml

Verify the template contains:

.StartsAt

inside:

range .Alerts
23. Verify the Rendered SMTP Configuration

Run:

grep -n -A15 "name: platform-email" 
/tmp/monitoring-assets-rendered.yaml

Expected structure:

name: platform-email
email_configs:

to: "..."
from: "..."
smarthost: "smtp-relay.brevo.com:587"
auth_username: "..."
auth_password_file: "/etc/alertmanager/secrets/alertmanager-secret/smtp-password"
require_tls: true
send_resolved: true

Do not print or commit the actual SMTP password.

Verify Alertmanager Configuration in the Pod

Run:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
grep -n -A15 -B5 "platform-email" 
/etc/alertmanager/config_out/alertmanager.env.yaml

You should see:

receiver: platform-email

and:

smtp-relay.brevo.com:587

and:

auth_password_file:

and:

templates:

/etc/alertmanager/configmaps/alertmanager-templates/*.tmpl

Verify Alertmanager Health

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

kubectl logs -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager --since=10m

Filter for notification problems:

kubectl logs -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
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

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool config routes test 
--alertmanager.url=http://localhost:9093 
severity=warning 
namespace=monitoring 
team=platform 
alertname=TestAlert

For a warning alert, the expected receiver is:

platform-email

This is an important troubleshooting step because an alert can exist in Alertmanager but still not be routed to email.

Firing a Manual Test Alert

The most reliable method used during testing was amtool.

Use:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool alert add AlertmanagerSubjectTest 
'severity=warning' 
'namespace=monitoring' 
'team=platform' 
'environment=dev' 
--annotation='summary=Subject Test' 
--annotation='description=Testing dynamic firing and resolved subjects' 
--alertmanager.url=http://localhost:9093
Important Git Bash note

Always use:

MSYS_NO_PATHCONV=1

when necessary on Windows Git Bash.

amtool Parser Warning

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

Verify the Test Alert

Query the alert:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool alert query 
'alertname="AlertmanagerSubjectTest"' 
--alertmanager.url=http://localhost:9093

Expected:

AlertmanagerSubjectTest

with:

active
31. Inspect Alert Details

Use:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool alert query 
'alertname="AlertmanagerSubjectTest"' 
--alertmanager.url=http://localhost:9093 
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

Verify Email Delivery Through Metrics

Alertmanager exposes notification metrics.

Check successful email notification attempts:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
wget -qO- http://localhost:9093/metrics |
grep 'alertmanager_notifications_total{integration="email"}'

Example:

alertmanager_notifications_total{integration="email"} 8

The exact number will change as more notifications are sent.

Check for Failed Email Notifications

Run:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
wget -qO- http://localhost:9093/metrics |
grep 'alertmanager_notification_requests_failed_total{integration="email"}'

The desired result is:

alertmanager_notification_requests_failed_total{integration="email"} 0

This was successfully achieved during testing.

This is one of the strongest indicators that the SMTP delivery mechanism itself is working.

Troubleshooting: Email Not Received

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

Yahoo Mail / Spam Behavior

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

kubectl get configmap alertmanager-templates 
-n monitoring 
-o jsonpath='{.data.email.tmpl}'

Then check the mounted file:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
cat /etc/alertmanager/configmaps/alertmanager-templates/email.tmpl

If the ConfigMap contains the new template but the mounted file does not, investigate the pod/mount.

If both contain the new template, the template is available to Alertmanager.

Troubleshooting: Template Error

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

Troubleshooting: StatefulSet Not Found

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

helm template charts/monitoring-assets 


/tmp/monitoring-assets-rendered.yaml

Check the SMTP receiver:

grep -n -A20 "platform-email" 
/tmp/monitoring-assets-rendered.yaml

Check the template:

grep -n "StartsAt" 
/tmp/monitoring-assets-rendered.yaml

Check for accidental unresolved Helm variables:

grep -n '${SMTP_' 
/tmp/monitoring-assets-rendered.yaml

The output should be empty if no unresolved ${SMTP_*} placeholders are being used.

GitOps Deployment Workflow

The normal workflow is:

Modify Helm configuration
↓

helm lint
↓

helm template
↓

Inspect rendered configuration
↓

git diff --check
↓

git add
↓

git commit
↓

git push
↓

Argo CD sync
↓

Verify Kubernetes resources
↓

Test Alertmanager
↓

Verify email

Example:

helm lint charts/monitoring-assets
helm template charts/monitoring-assets 


/tmp/monitoring-assets-rendered.yaml
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

Final Testing Procedure

For a quick future smoke test:

Create alert
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool alert add AlertmanagerSmokeTest 
'severity=warning' 
'namespace=monitoring' 
'team=platform' 
'environment=dev' 
--annotation='summary=Alertmanager Smoke Test' 
--annotation='description=Testing Alertmanager email delivery' 
--alertmanager.url=http://localhost:9093
Verify alert
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool alert query 
'alertname="AlertmanagerSmokeTest"' 
--alertmanager.url=http://localhost:9093
Verify routing
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool config routes test 
--alertmanager.url=http://localhost:9093 
severity=warning 
namespace=monitoring 
team=platform 
alertname=AlertmanagerSmokeTest

Expected:

platform-email
Verify notification failures
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
wget -qO- http://localhost:9093/metrics |
grep 'alertmanager_notification_requests_failed_total{integration="email"}'

Expected:

... 0
Expire the test
MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-alertmanager-0 
-c alertmanager -- 
amtool alert expire 
'alertname="AlertmanagerSmokeTest"' 
--alertmanager.url=http://localhost:9093

Important: use the actual pod name:

alertmanager-prometheus-stack-kube-prom-alertmanager-0

so the complete command should be:

MSYS_NO_PATHCONV=1 kubectl exec -n monitoring 
alertmanager-prometheus-stack-kube-prom-alertmanager-0 
-c alertmanager -- 
amtool alert expire 
'alertname="AlertmanagerSmokeTest"' 
--alertmanager.url=http://localhost:9093

Because:

send_resolved: true

you should receive the resolved notification.

Lessons Learned

Several important lessons came out of this implementation.

Helm .Files.Get does not automatically evaluate Helm expressions

Use:

tpl (.Files.Get "file") .

when a file contains Helm template expressions.

Alertmanager template context matters

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

Always validate rendered Helm output

A successful:

helm lint

does not guarantee that the final rendered configuration is exactly what you expect.

Use:

helm template

and inspect the output.

Kubernetes generated names matter

Do not assume the StatefulSet name.

Use:

kubectl get statefulsets -n monitoring

before attempting a restart.

Git Bash can modify Linux paths

On Windows:

MSYS_NO_PATHCONV=1

can be necessary when using kubectl exec with container paths.

Alert existence does not guarantee email delivery

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

Final State

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

47. Updated Observability Validation — August 14, 2026

The original Alertmanager implementation has now been extended and validated as part of the broader Kubernetes observability stack.

The original design remains unchanged:

AWS Secrets Manager
        |
        v
External Secrets Operator
        |
        v
alertmanager-secret
        |
        v
Alertmanager
        |
        v
Brevo SMTP
        |
        v
Email recipient

This remains the authoritative secret-management architecture. SMTP credentials are not being moved into Git.

47.1 Prometheus / Kubernetes Metrics

The cluster currently has three Ready worker nodes:

ip-10-0-3-227.ec2.internal
ip-10-0-4-225.ec2.internal
ip-10-0-4-93.ec2.internal

Kubelet and kube-state-metrics data are available.

Validated metrics include:

kube_pod_info
kubelet_running_pods
kube_node_status_allocatable{resource="pods"}

The current pod counts observed were:

ip-10-0-4-225.ec2.internal   17
ip-10-0-4-93.ec2.internal    15
ip-10-0-3-227.ec2.internal   17

Each node currently reports a pod capacity/allocatable value of 17.

An attempted query:

kubelet_running_pods / kubelet_pod_worker_limit * 100

returned no data because kubelet_pod_worker_limit is not available in the current metric set.

This is not a Prometheus failure. The available kubelet and kube-state-metrics metrics were verified independently.

47.2 Loki ServiceMonitor

The Loki ServiceMonitor was validated successfully.

Prometheus reported:

8 / 8 up

The targets included Loki and Loki canary endpoints.

All observed targets were:

up = 1

This confirms that Prometheus is successfully scraping Loki metrics.

The Loki monitoring path is therefore considered working.

47.3 KubeSchedulerDown / KubeControllerManagerDown Investigation

The cluster initially generated:

KubeSchedulerDown
KubeControllerManagerDown

Queries such as:

up{job=~".*scheduler.*"}

and:

count(up{job="kube-scheduler"})

returned no scheduler target.

The important EKS-specific point is that the Kubernetes scheduler and controller manager are AWS-managed control-plane components and are not exposed as ordinary worker-node workloads.

The GitOps values file contains:

defaultRules:
  create: true
  rules:
    kubeControllerManager: false
    kubeScheduler: false

However, an existing generated PrometheusRule was still found containing:

- alert: KubeSchedulerDown
  expr: absent(up{job="kube-scheduler"} == 1)
  for: 15m

This demonstrated an important troubleshooting distinction: the Git values, Helm-rendered output, Argo CD desired state, and Kubernetes live state must all be checked independently.

The chart version was verified as:

kube-prometheus-stack 77.12.0

The chart defaults were also inspected and showed separate scheduler-related controls:

kubeSchedulerAlerting
kubeSchedulerRecording

The live rule eventually reconciled away and the alert resolved.

Final verification:

ALERTS{alertname=~"KubeSchedulerDown|KubeControllerManagerDown"}

returned no data.

The Prometheus stack Application was also verified:

Synced Healthy

Lesson

When a default monitoring rule appears unexpectedly:

Check the Git values.

Check origin/main.

Check the Argo CD Application.

Render the Helm chart.

Inspect the live PrometheusRule.

Allow Argo CD reconciliation/pruning.

Re-query Prometheus.

Do not redesign the monitoring architecture simply because a generated rule takes time to reconcile.

48. End-to-End Monitoring Test

After the Alertmanager and Prometheus configuration was stable, a temporary synthetic alert was created to test the complete notification path.

The temporary rule was:

apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: monitoring-e2e-test
  namespace: monitoring
  labels:
    release: prometheus-stack
spec:
  groups:
    - name: monitoring-e2e-test
      rules:
        - alert: MonitoringE2ETest
          expr: vector(1)
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "Monitoring E2E test alert"
            description: "This is a temporary end-to-end monitoring test."

It was applied temporarily with:

kubectl apply -f /tmp/monitoring-e2e-test.yaml

Prometheus correctly evaluated the rule.

The alert progressed from:

pending

to:

firing

The Prometheus query:

ALERTS{alertname="MonitoringE2ETest"}

confirmed the firing state.

48.1 Firing Email

The firing alert generated an actual email.

The email contained:

ALERT FIRING
MonitoringE2ETest

and included:

Environment: development
Cluster: devops-cluster
Severity: WARNING

The labels included:

alertname     = MonitoringE2ETest
cluster       = devops-cluster
environment   = development
prometheus    = monitoring/prometheus-stack-kube-prom-prometheus
severity      = warning

This proved:

PrometheusRule
    |
    v
Prometheus evaluation
    |
    v
Alertmanager
    |
    v
platform-email
    |
    v
Brevo SMTP
    |
    v
Yahoo Mail

48.2 Alertmanager API Validation

Alertmanager was also checked through its API:

curl http://localhost:9093/api/v2/alerts

The test alert appeared with:

receiver = platform-email
state    = active

This independently confirmed that Alertmanager had received and routed the alert.

48.3 Resolved Email

After the firing test was confirmed, the temporary PrometheusRule was deleted:

kubectl delete prometheusrule \
  -n monitoring \
  monitoring-e2e-test

Prometheus then returned no data for:

ALERTS{alertname="MonitoringE2ETest"}

Alertmanager subsequently generated the resolved notification.

The resolved email contained:

ALERT RESOLVED
MonitoringE2ETest

with:

Started:  2026-08-14 22:15:04 UTC
Resolved: 2026-08-14 22:25:04 UTC

This confirms that:

send_resolved: true

is working.

49. Final E2E Result

The complete monitoring notification pipeline has now been validated:

Component

Result

PrometheusRule accepted

PASS

Prometheus evaluated rule

PASS

Pending → firing transition

PASS

Alertmanager received alert

PASS

Alert routed to platform-email

PASS

SMTP authentication

PASS

Brevo SMTP delivery

PASS

Firing email received

PASS

Test rule deleted

PASS

Alert cleared from Prometheus

PASS

Resolved notification generated

PASS

Resolved email received

PASS

The observability notification pipeline is therefore considered validated end-to-end.

50. Node Deletion Testing Decision

A worker-node deletion test was considered.

The concern was that an EKS managed node group could replace a deleted worker before a long-duration alert threshold was reached.

That concern is valid.

However, a node deletion is not required to prove that the notification pipeline works. The synthetic MonitoringE2ETest already exercised the entire path from Prometheus through Alertmanager, SMTP, email delivery, and resolution.

Therefore:

Do not change production alert thresholds simply to make manual node-deletion testing easier.

If node resilience needs to be tested later, it should be treated as a separate infrastructure-resilience test rather than as the primary Alertmanager validation.

51. Current Observability State

The current validated architecture is:

Kubernetes
    |
    +--> kubelet metrics
    +--> kube-state-metrics
    +--> node-exporter
    +--> Loki metrics
    |
    v
Prometheus
    |
    +--> Grafana
    |
    +--> Alert rules
    |
    v
Alertmanager
    |
    v
platform-email
    |
    v
Brevo SMTP
    |
    v
Yahoo Mail

Logs:

Kubernetes workloads
        |
        v
Promtail
        |
        v
Loki
        |
        v
Grafana

Secrets:

AWS Secrets Manager
        |
        v
External Secrets Operator
        |
        v
alertmanager-secret
        |
        v
Alertmanager

Argo CD:

prometheus-stack = Synced / Healthy

Loki monitoring:

ServiceMonitor = 8 / 8 up

The observability stack is considered complete for the current project phase.

52. Key Lessons From the Complete Implementation

52.1 Helm rendering is part of troubleshooting

A value can be correct in Git while the generated Kubernetes resource still contains an unexpected rule.

Always compare:

Git values
    |
    v
Helm rendered YAML
    |
    v
Argo CD desired state
    |
    v
Kubernetes live resource
    |
    v
Prometheus behavior

52.2 Chart defaults can contain multiple related rule groups

For kube-prometheus-stack, scheduler-related rules are not necessarily controlled by one setting alone.

Inspect the chart version in use:

helm show values prometheus-community/kube-prometheus-stack \
  --version 77.12.0

52.3 Missing metrics do not automatically indicate failure

If a query returns no data, first determine whether the metric exists.

For example:

kubelet_pod_worker_limit

was not available, while:

kubelet_running_pods
kube_node_status_allocatable{resource="pods"}

were available.

52.4 Alert firing and notification delivery are different layers

The following must be validated separately:

Rule evaluation
      |
      v
Alert firing
      |
      v
Alertmanager receipt
      |
      v
Route selection
      |
      v
SMTP notification
      |
      v
Email delivery

The E2E test proved every layer.

52.5 Firing and resolved notifications both matter

The final test proved both:

ALERT FIRING

and:

ALERT RESOLVED

This is especially important because the platform uses:

send_resolved: true

52.6 Temporary tests should be removed

The E2E PrometheusRule was intentionally created outside Git for controlled testing.

After validation:

kubectl delete prometheusrule \
  -n monitoring \
  monitoring-e2e-test

The rule was confirmed absent from Prometheus afterward.

52.7 Do not redesign a working architecture

The final observability architecture is now proven.

Future work should build on:

Prometheus
Alertmanager
Grafana
Loki
Promtail
Argo CD
External Secrets
AWS Secrets Manager

rather than replacing working components without a concrete requirement.

53. Final Status

Observability & Alerting: VALIDATED

Prometheus                         ✓
Kubernetes metrics                 ✓
Kubelet metrics                    ✓
kube-state-metrics                 ✓
Loki ServiceMonitor                ✓ 8/8 up
Grafana                            ✓
Alert rules                        ✓
Alertmanager                       ✓
Alert routing                      ✓
SMTP authentication                ✓
Brevo SMTP delivery                ✓
Firing email                       ✓
Resolved email                     ✓
Argo CD                            ✓ Synced / Healthy
External Secrets                   ✓
AWS Secrets Manager                ✓
Synthetic E2E test                 ✓

The monitoring and alerting capability should now be treated as a completed platform capability.

The next project work should move forward to the next unfinished platform capability rather than continuing to redesign or retest the observability architecture.