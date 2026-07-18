# Alertmanager

# Overview

Alertmanager is the notification and alert routing component of the Prometheus ecosystem.

While Prometheus is responsible for evaluating alert rules and determining when an alert has fired, Alertmanager is responsible for deciding what should happen next.

Its responsibilities include:

- Receiving alerts from Prometheus
- Grouping similar alerts
- Routing alerts to the appropriate receiver
- Sending notifications
- Suppressing duplicate alerts
- Silencing alerts during maintenance
- Managing notification frequency

Without Alertmanager, Prometheus would simply detect problems without notifying anyone.

Alertmanager completes the monitoring pipeline by ensuring operational issues reach the correct engineering teams.

---

# Objectives

The Enterprise Platform implements Alertmanager to achieve the following objectives:

- Deliver actionable notifications
- Reduce alert fatigue
- Prevent duplicate notifications
- Route alerts to the appropriate teams
- Support multiple notification channels
- Improve Mean Time To Detection (MTTD)
- Improve Mean Time To Recovery (MTTR)
- Integrate alerting into the GitOps workflow

---

# Alerting Architecture

The Enterprise Platform follows the architecture below.

```
Spring Boot Applications

↓

Micrometer

↓

Prometheus

↓

Recording Rules

↓

Alert Rules

↓

Alertmanager

↓

Notification Routing

↓

Slack / Email / PagerDuty

↓

Platform Engineer
```

Every component has a clearly defined responsibility.

---

# Alertmanager Responsibilities

Alertmanager does not evaluate metrics.

Its responsibilities begin only after Prometheus determines that an alert has fired.

Alertmanager is responsible for:

- Routing alerts
- Grouping alerts
- Deduplicating alerts
- Delaying notifications
- Repeating notifications
- Silencing alerts
- Inhibiting related alerts
- Formatting notifications

---

# Routing

Routing determines where an alert should be sent.

Different alerts often require different operational responses.

Example routing strategy:

```
Critical Alerts

↓

Platform On-call Engineer

↓

Slack + Email

--------------------------------

Warning Alerts

↓

Platform Team

↓

Slack

--------------------------------

Informational Alerts

↓

Dashboard Only
```

Routing ensures that alerts reach the appropriate audience without overwhelming every engineer.

---

# Receivers

A receiver defines the destination for an alert.

Common receivers include:

- Email
- Slack
- Microsoft Teams
- PagerDuty
- Opsgenie
- Discord
- Generic Webhooks

The Enterprise Platform initially supports:

- Email
- Slack

Additional receivers can be introduced without modifying Prometheus alert rules.

---

# Alert Grouping

One of Alertmanager's most important features is grouping.

Consider the following scenario.

A Kubernetes node fails.

Without grouping:

```
Node Down

Pod 1 Down

Pod 2 Down

Pod 3 Down

Deployment Failed

PVC Warning

DaemonSet Warning

...

50 Individual Notifications
```

Engineers receive dozens of notifications for a single infrastructure failure.

With grouping:

```
Node Failure

Affected Resources:

• 47 Pods

• 8 Deployments

• 2 DaemonSets

• 4 PVC Alerts

One Notification
```

Grouping significantly reduces notification noise and improves operational efficiency.

---

# Deduplication

Alertmanager automatically removes duplicate alerts.

Suppose two Prometheus replicas detect the same issue.

Without deduplication:

```
Alert A

Alert A

Alert A
```

With deduplication:

```
Alert A
```

Only one notification is delivered.

---

# Repeat Interval

Sometimes an issue remains unresolved for an extended period.

Alertmanager prevents notification spam by controlling how frequently reminders are sent.

Example:

```
Disk Full

↓

Notification

↓

4 Hours

↓

Reminder

↓

4 Hours

↓

Reminder
```

Instead of receiving notifications every few seconds, engineers receive periodic reminders until the issue is resolved.

---

# Inhibition

Inhibition prevents secondary alerts from creating unnecessary noise.

Example:

A Kubernetes node becomes unavailable.

As a result:

- Pods become unavailable
- Deployments become unavailable
- Services become unavailable

Without inhibition:

```
Node Down

↓

Pod Down

↓

Deployment Down

↓

Service Down

↓

PVC Warning
```

Five notifications are generated.

With inhibition:

```
Node Down
```

Only the root cause is reported.

Engineers investigate the node failure first, knowing the other alerts are consequences of that event.

---

# Silences

Silences temporarily suppress alerts.

This feature is commonly used during:

- Planned maintenance
- Cluster upgrades
- Application deployments
- Database migrations
- Disaster recovery testing

Rather than disabling monitoring, Alertmanager temporarily suppresses notifications while continuing to evaluate alerts.

Once the maintenance window ends, alerts resume automatically.

---

# Notification Templates

Raw alerts are difficult to read.

Notification templates allow Alertmanager to generate clear, human-readable notifications.

A notification typically includes:

- Alert name
- Severity
- Summary
- Description
- Namespace
- Cluster
- Dashboard link
- Runbook link

Well-designed templates significantly improve incident response.

---

# Notification Channels

The Enterprise Platform is designed to support multiple notification channels.

Current channels:

- Email
- Slack

Future integrations may include:

- PagerDuty
- Opsgenie
- Microsoft Teams
- Discord
- Generic Webhooks

The routing configuration determines which alerts are delivered to which receiver.

---

# Severity-Based Routing

Different alert severities require different operational responses.

The Enterprise Platform defines three severity levels.

## Info

Informational events.

Examples:

- Backup completed
- New deployment
- Node joined cluster

These events typically do not trigger notifications.

---

## Warning

Warning alerts indicate that engineers should investigate a potential issue before it becomes critical.

Examples:

- CPU above 80%
- Memory above 85%
- Increased request latency
- Disk utilization above 80%

Warnings are generally routed to team communication channels.

---

## Critical

Critical alerts require immediate attention.

Examples:

- Node unavailable
- Application unavailable
- Deployment failure
- Persistent HTTP 500 errors

Critical alerts are routed to the on-call engineer and delivered through multiple notification channels.

---

# Alertmanager Configuration

The Alertmanager configuration defines:

- Routes
- Receivers
- Grouping
- Repeat intervals
- Inhibition rules
- Notification templates

In the Enterprise Platform, this configuration is managed through Git and deployed automatically using Helm and Argo CD.

This ensures that alert routing remains version-controlled and reproducible.

---

# Security Considerations

Notification credentials should never be stored in Git.

Examples include:

- SMTP passwords
- Slack Webhooks
- PagerDuty API Keys
- Teams Webhooks

Instead, credentials should be stored securely using:

- AWS Secrets Manager
- Kubernetes Secrets
- External Secrets Operator
- HashiCorp Vault

Only references to those secrets should exist within the repository.

---

# Operational Workflow

The complete alerting workflow is shown below.

```
Application

↓

Micrometer

↓

Prometheus

↓

Recording Rules

↓

Alert Rules

↓

Alertmanager

↓

Routing

↓

Grouping

↓

Receiver

↓

Notification

↓

Engineer

↓

Incident Response

↓

Issue Resolved
```

Every stage in the workflow is automated and managed through GitOps.

---

# Validation

After Argo CD synchronizes the Alertmanager configuration, verify that the Alertmanager configuration has been deployed successfully.

List the Alertmanager configuration resources:

```bash
kubectl get alertmanagerconfig -n monitoring
```

Inspect the configuration:

```bash
kubectl describe alertmanagerconfig enterprise-alertmanager -n monitoring
```

Verify that:

- Routes are present
- Receivers are configured
- Grouping parameters are applied
- No validation errors are reported

Next, verify that Alertmanager itself is running:

```bash
kubectl get pods -n monitoring
```

Locate the Alertmanager pod:

```
prometheus-stack-kube-prom-alertmanager-0
```

Confirm that it is in the **Running** state.

Once deployed, Alertmanager will automatically receive alerts generated by Prometheus.

---

# Best Practices

The Enterprise Platform follows these Alertmanager best practices.

## Route Alerts by Team

Different engineering teams should receive only the alerts relevant to their services.

---

## Use Severity Levels

Always distinguish between:

- Info
- Warning
- Critical

This prevents operational overload.

---

## Group Related Alerts

Group alerts whenever possible to reduce notification noise.

---

## Configure Repeat Intervals

Avoid repeatedly notifying engineers about the same unresolved issue.

---

## Use Notification Templates

Every notification should include:

- Summary
- Description
- Severity
- Dashboard Link
- Runbook Link

Well-formatted notifications reduce investigation time.

---

## Keep Secrets Out of Git

Never commit credentials.

Use secure secret management solutions instead.

---

## Version Control Everything

Alertmanager configuration should always be managed through Git.

Changes should be reviewed, approved, and deployed through Argo CD.

---

# Enterprise Benefits

Implementing Alertmanager provides several operational advantages.

- Automated incident notification
- Reduced alert fatigue
- Intelligent routing
- Notification deduplication
- Easier incident response
- Consistent operational procedures
- GitOps-managed alert routing
- Secure secret management
- Scalable notification architecture

These capabilities ensure that the observability platform can continue to scale as additional services, environments, and engineering teams are introduced.

---

# Summary

Alertmanager is the final stage of the Enterprise Platform's monitoring and alerting pipeline.

It transforms Prometheus alerts into actionable notifications by intelligently grouping, routing, deduplicating, and formatting alerts before delivering them to engineers.

By managing Alertmanager configuration through Helm and Argo CD, the platform ensures that alert routing remains reproducible, auditable, secure, and fully aligned with GitOps and Infrastructure-as-Code best practices.

As the platform grows, Alertmanager provides the flexibility to integrate additional notification channels, implement sophisticated routing policies, and support enterprise-scale operational workflows while maintaining a consistent and maintainable observability architecture.