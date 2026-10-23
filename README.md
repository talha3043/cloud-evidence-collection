# Lab 7 - Dual-Path CV Deployment on AWS

## Architecture & Request Flow

```
[ Client Browser ]
      |
      +---> HTTP (Port 80) ---> [ EC2 Instance: Apache ]
      |                                ^
      |                                | (Cron Sync every 5m)
      |                                v
      |                         [ Private S3 Bucket: site/ ]
      |                                ^
      |                                | (boto3 GetObject)
      +---> HTTPS (Auth: NONE) -> [ Lambda Function URL ]
```

- **EC2 Path:** An incoming HTTP request hits Apache on port 80 of the EC2 instance, which serves static assets synchronized from the private S3 bucket every 5 minutes with the instance ID dynamically stamped in the footer.
- **Lambda Path:** An incoming HTTPS request hits the Lambda Function URL, executing the Python handler to dynamically retrieve the object from the private S3 bucket, format the required MIME headers/base64 encoding, and return it directly.

---

## AWS CLI Verification (Access Denied)

Command run from EC2 shell:
```bash
aws s3 rm s3://cv-23l-3043/site/index.html
```

Output:
```text
delete failed: s3://cv-23l-3043/site/index.html An error occurred (AccessDenied) when calling the DeleteObject operation: Access Denied
```

---

## Sync Logs (`/var/log/cv-sync.log`)

```text
2026-10-23 10:00:01 - Sync SUCCESS
2026-10-23 10:05:01 - Sync SUCCESS
2026-10-23 10:10:01 - Sync SUCCESS
2026-10-23 10:15:01 - Sync SUCCESS
2026-10-23 10:20:01 - Sync SUCCESS
2026-10-23 10:25:01 - Sync SUCCESS
2026-10-23 10:30:01 - Sync SUCCESS
2026-10-23 10:35:01 - Sync SUCCESS
2026-10-23 10:40:01 - Sync SUCCESS
2026-10-23 10:45:01 - Sync SUCCESS
```

---

## Written Questions & Answers

### 1. Why do the instance and the function use roles instead of access keys? What could go wrong if the keys were in the user data?
IAM roles issue short-lived, automatically rotated credentials through the instance metadata service and execution runtime, eliminating static secrets. If long-term access keys were placed in user data or repository files, anyone with read access to instance metadata, script logs, or GitHub could exfiltrate them and compromise the AWS account.

### 2. Someone pastes the S3 address of index.html into a browser. What do they see, and which setting causes that?
The visitor sees an `HTTP 403 Forbidden` / `AccessDenied` XML error page. This is caused by having S3 **Block Public Access** fully enabled, which overrides any public permissions and ensures no unauthenticated client can read objects directly from S3.

### 3. Explain in your own words the permission on the function URL that lets anyone call it. Why is that acceptable for the function but not for the bucket?
The Function URL uses a resource policy granting `lambda:InvokeFunctionUrl` to principal `*` with `AuthType NONE`. This is safe because Lambda acts as an application gateway with code-level access validation and rate controls, whereas granting public access to the S3 bucket exposes the raw storage layer to uncontrolled downloads, data leakage, and potential storage attacks.

### 4. Compare the two paths. What do you pay for when nobody visits the site? What happens if the traffic grows a hundred times?
With zero visitors, EC2 continues billing hourly for instance uptime and attached EBS storage, whereas Lambda costs $0.00 since compute is billed strictly per millisecond of invocation. If traffic spikes 100x, Lambda automatically scales concurrently to handle the load (with linear cost growth), while the single EC2 instance risks CPU starvation, connection queuing, and downtime without auto-scaling.

### 5. You delete the EC2 instance. What do you lose and what do you still have?
Deleting the instance destroys the virtual machine, its root EBS storage, the local Apache server, and local sync logs. However, the private S3 bucket, uploaded CV files, IAM roles, CloudWatch logs, and the serverless Lambda deployment remain intact and fully operational.
