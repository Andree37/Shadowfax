# File Upload Setup - AWS S3 with STS AssumeRole

## Overview

This application uses **AWS STS AssumeRole** for S3 file uploads. This provides:

- ✅ **Temporary credentials** that auto-expire (default: 1 hour)
- ✅ **Automatic credential rotation** (refreshes 5 minutes before expiry)
- ✅ **Zero long-lived credentials** in production (when using instance profiles)
- ✅ **Minimal permissions** on base credentials (only `sts:AssumeRole`)
- ✅ **Full audit trail** via AWS CloudTrail

**No other authentication methods are supported.** This is by design for maximum security.

---

## AWS Setup

### 1. Create S3 Bucket

1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Navigate to **S3** → **Create bucket**
3. Configure:
   - **Bucket name**: `shadowfax-uploads-prod` (or your choice)
   - **Region**: `us-east-1` (or your preferred region)
   - **Block Public Access**: Uncheck "Block all public access" (for public file URLs)
   - Acknowledge the warning
4. Click **Create bucket**

### 2. Configure Bucket CORS

1. Go to your bucket → **Permissions** tab
2. Scroll to **Cross-origin resource sharing (CORS)**
3. Click **Edit** and paste:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag"]
  }
]
```

4. Click **Save changes**

### 3. Create IAM Role for S3 Access (Role to Assume)

This is the role that will have actual S3 permissions.

1. Go to **IAM** → **Roles** → **Create role**
2. Select **Custom trust policy**
3. Paste this trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Note**: Replace `YOUR_ACCOUNT_ID` with your AWS account ID. This allows any principal in your account to assume the role (we'll restrict it further with IAM policies).

4. Click **Next**
5. Click **Create policy** (opens new tab) and paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME"
    }
  ]
}
```

6. Replace `YOUR_BUCKET_NAME` with your actual bucket name
7. Name the policy: `shadowfax-s3-upload-policy`
8. Go back to the role creation tab
9. Refresh policies and select `shadowfax-s3-upload-policy`
10. Click **Next**
11. Name the role: `shadowfax-s3-upload-role`
12. Click **Create role**
13. **Copy the Role ARN** (e.g., `arn:aws:iam::123456789:role/shadowfax-s3-upload-role`)

---

## Production Setup Quick Reference(EC2/ECS/Lambda/EKS)

### STS AssumeRole (Most Secure - Recommended)

```bash
USE_STS=true
AWS_ROLE_ARN=arn:aws:iam::123456789:role/shadowfax-s3-upload-role
AWS_ACCESS_KEY_ID=base-user-access-key-id
AWS_SECRET_ACCESS_KEY=base-user-secret-key
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
```

### STS with Instance Profile (AWS hosting - No static credentials)

```bash
USE_STS=true
USE_IAM_ROLE=true
AWS_ROLE_ARN=arn:aws:iam::123456789:role/shadowfax-s3-upload-role
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
```

### IAM Instance Profile Only (AWS hosting)
**Best option** - No static credentials needed at all!

### For EC2 Instances

1. **Create IAM Role for EC2**:
   - Go to **IAM** → **Roles** → **Create role**
   - Select **AWS service** → **EC2**
   - Click **Next**
   - Create inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::123456789:role/shadowfax-s3-upload-role"
    }
  ]
}
```

   - Name the role: `shadowfax-ec2-instance-role`
   - Click **Create role**

2. **Attach Role to EC2 Instance**:
   - Go to **EC2** → Select your instance
   - **Actions** → **Security** → **Modify IAM role**
   - Select `shadowfax-ec2-instance-role`
   - Click **Update IAM role**

3. **Set Environment Variables**:

```bash
USE_IAM_ROLE=true
AWS_ROLE_ARN=arn:aws:iam::123456789:role/shadowfax-s3-upload-role
AWS_REGION=us-east-1
S3_BUCKET_NAME=shadowfax-uploads-prod
```

### ForECS/Fargate

1. **Create Task Role**:
   - Go to **IAM** → **Roles** → **Create role**
   - Select **Elastic Container Service** → **Elastic Container Service Task**
   - Attach inline policy (same AssumeRole policy as above)
   - Name: `shadowfax-ecs-task-role`

2. **Update Task Definition**:
   - Add the role ARN to `taskRoleArn` field

3. **Environment Variables**:

USE_IAM_ROLEtrueAWS_ROLE_ARNarn:aws:iam::123456789:role/shadowfaxs3uploadroleshadowfaxuploadsprod### For Lambda

1. Update Lambda Execution Role**:
   - Add the AssumeRole permission to your Lambda's execution role
   - Same policy as above

2. **Environment VariablesinLambdaconfig

```bash
USE_IAM_ROLE=true
AWS_ROLE_ARN=arn:aws:iam::123456789:role/shadowfax-s3-upload-role
AWS_REGION=us-east-1
S3_BUCKET_NAME=shadowfax-uploads-prod
```

### For EKS (Kubernetes)

1. **Set up IRSA** (IAM Roles for Service Accounts):
   - Create IAM role with AssumeRole permission
   - Set up trust relationship with your EKS cluster's OIDC provider
   - Annotate your Kubernetes service account

2. **Pod Environment Variables**:

```yaml
env:
  - name: USE_IAM_ROLE
    value: "true"
  - name: AWS_ROLE_ARN
    value: "arn:aws:iam::123456789:role/shadowfax-s3-upload-role"
  - name: AWS_REGION
    value: "us-east-1"
  - name: S3_BUCKET_NAME
    value: "shadowfax-uploads-prod"
```

---

## Development Setup

For local development, you need base credentials with **only** `sts:AssumeRole` permission.

### 1. Create Base IAM User

1. Go to **IAM** → **Users** → **Create user**
2. User name: `shadowfax-dev-sts-user`
3. Select **Access key - Programmatic access**
4. Click **Next**
5. Click **Attach policies directly** → **Create policy**
6. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::123456789:role/shadowfax-s3-upload-role"
    }
  ]
}
```

7. Name the policy: `shadowfax-dev-assume-role-policy`
8. Go back and attach the policy to the user
9. Click **Create user**
10. **Save the Access Key ID and Secret Access Key**

### 2. Set Environment Variables

Create a `.env` file (add to `.gitignore`):

```bash
AWS_ROLE_ARN=arn:aws:iam::123456789:role/shadowfax-s3-upload-role
AWS_ACCESS_KEY_ID=AKIA...  # Base user credentials
AWS_SECRET_ACCESS_KEY=...   # Base user credentials
AWS_REGION=us-east-1
S3_BUCKET_NAME=shadowfax-uploads-dev
```

**Important**: This IAM user has **ZERO S3 permissions**. It can only assume the role to get temporary credentials.

---

## Environment Variables Reference

### Production (EC2/ECS/Lambda/EKS)

```bash
USE_IAM_ROLE=true
AWS_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/shadowfax-s3-upload-role
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
AWS_SESSION_DURATION=3600  # Optional: 3600-43200 seconds (1-12 hours)
```

### Development (Local)

```bash
AWS_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/shadowfax-s3-upload-role
AWS_ACCESS_KEY_ID=your-base-user-key-id
AWS_SECRET_ACCESS_KEY=your-base-user-secret
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
AWS_SESSION_DURATION=3600  # Optional: 3600-43200 seconds (1-12 hours)
```

---

## Installation

Run this command to install dependencies:

```bash
mix deps.get
```

---

## API Usage

### Method 1: Direct Upload (Smaller Files)

Upload file through your server:

```bash
POST /api/upload
Content-Type: multipart/form-data

file: <binary file data>
```

**Response:**
```json
{
  "success": true,
  "attachment": {
    "id": "uuid",
    "filename": "image.png",
    "url": "https://bucket.s3.region.amazonaws.com/uploads/...",
    "content_type": "image/png",
    "size": 12345,
    "s3_key": "uploads/2025/01/15/timestamp-uuid.png"
  }
}
```

### Method 2: Presigned URL (Recommended for Larger Files)

1. Request presigned URL:

```bash
POST /api/upload/presigned
Content-Type: application/json

{
  "filename": "image.png",
  "content_type": "image/png"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "upload_url": "https://bucket.s3.amazonaws.com/uploads/...?X-Amz-...",
    "s3_key": "uploads/2025/01/15/timestamp-uuid.png",
    "filename": "image.png",
    "content_type": "image/png"
  }
}
```

2. Upload directly to S3:

```bash
PUT <upload_url>
Content-Type: image/png

<binary file data>
```

3. Send message with attachment:

```bash
POST /api/channels/:id/messages
Content-Type: application/json

{
  "message": {
    "content": "Check out this image!",
    "attachments": [{
      "id": "uuid",
      "filename": "image.png",
      "url": "https://bucket.s3.region.amazonaws.com/uploads/...",
      "content_type": "image/png",
      "size": 12345,
      "s3_key": "uploads/2025/01/15/timestamp-uuid.png"
    }]
  }
}
```

---

## Allowed File Types

### Images
- image/png
- image/jpeg
- image/jpg
- image/gif
- image/webp

### Documents
- application/pdf
- text/plain
- application/msword (DOC)
- application/vnd.openxmlformats-officedocument.wordprocessingml.document (DOCX)
- application/vnd.ms-excel (XLS)
- application/vnd.openxmlformats-officedocument.spreadsheetml.sheet (XLSX)

**Maximum file size**: 50MB

---

## How It Works

### STS Credential Flow

```
Application Startup
  ↓
GenServer starts (Shadowfax.AWS.STSCredentials)
  ↓
Calls sts:AssumeRole with base credentials
  ↓
Receives temporary credentials (expires in 1 hour)
  ↓
Stores credentials in memory
  ↓
Auto-refreshes 5 minutes before expiry
  ↓
Upload requests use temporary credentials
```

### Security Benefits

1. **Base credentials** (IAM user or instance profile):
   - Only permission: `sts:AssumeRole`
   - Cannot access S3 directly
   - Useless if compromised

2. **Temporary credentials** (from STS):
   - Full S3 permissions (PutObject, GetObject, DeleteObject)
   - Auto-expire in 1 hour (configurable 1-12 hours)
   - Auto-rotate before expiry
   - Never persisted to disk

3. **Audit trail**:
   - All AssumeRole calls logged in CloudTrail
   - Can track who/when/where credentials were issued

---

## Troubleshooting

### "AWS_ROLE_ARN is required" error

**Cause**: Missing `AWS_ROLE_ARN` environment variable

**Fix**: Set the role ARN in your environment variables

### "AWS_ACCESS_KEY_ID is required when USE_IAM_ROLE is not set"

**Cause**: Running locally without base credentials

**Fix**: Create an IAM user with AssumeRole permission and set credentials in `.env`

### "Failed to assume role" error

**Cause**: Base credentials don't have permission to assume the role

**Fix**:
1. Verify the trust policy on the target role allows your base user/role
2. Verify base user/role has `sts:AssumeRole` permission for the target role ARN

### "Access Denied" when uploading

**Cause**: The assumed role doesn't have S3 permissions

**Fix**: Verify the S3 policy is attached to the assumed role (not the base user)

### Files not accessible

**Cause**: Bucket permissions or ACL issues

**Fix**:
1. Verify bucket allows public read access
2. Check that uploads set `acl: public-read`

---

## .gitignore

Make sure your `.gitignore` includes:

```
.env
.env.*
!.env.example
```

Never commit AWS credentials to version control!
