# Security & Token Management Guide

## Table of Contents
1. [JWT Token Management](#jwt-token-management)
2. [Secret Key Rotation](#secret-key-rotation)
3. [Token Blacklisting](#token-blacklisting)
4. [Environment Configuration](#environment-configuration)
5. [Emergency Procedures](#emergency-procedures)
6. [Maintenance Tasks](#maintenance-tasks)
7. [Best Practices](#best-practices)

---

## JWT Token Management

### Token Architecture

Shadowfax uses a **dual-token system** for enhanced security:

- **Access Token**: Short-lived (15 minutes), used for API requests
- **Refresh Token**: Long-lived (30 days), used to obtain new access tokens

### Token Storage

All tokens are stored in the database (`auth_tokens` table) with:
- Hashed token values (SHA-256)
- Expiration timestamps
- Token type and version
- Device info and IP address
- Last used timestamp

### Token Lifecycle

```
1. User Login/Register
   ├─> Generate access_token (15 min TTL)
   ├─> Generate refresh_token (30 day TTL)
   └─> Store both tokens in database (hashed)

2. Access Token Expires
   ├─> Client sends refresh_token to /api/auth/refresh
   ├─> Server validates refresh_token
   ├─> Generate new access_token + refresh_token
   └─> Invalidate old refresh_token

3. User Logout
   ├─> Token added to blacklist
   ├─> Token deleted from database
   └─> Optional: Revoke all user tokens
```

---

## Secret Key Rotation

### When to Rotate Secrets

Rotate secrets in these scenarios:
- **Immediate**: Security breach or suspected compromise
- **Regular**: Every 90 days (recommended)
- **Team Changes**: When developers leave the project
- **Compliance**: As required by security policies

### Step-by-Step Rotation Process

#### 1. Rotate TOKEN_SALT

```bash
# Generate a new salt
mix phx.gen.secret

# Set TOKEN_VERSION to 2 (increment by 1)
export TOKEN_VERSION=2
export TOKEN_SALT="new_generated_salt_here"

# Restart application
# Old tokens will still work during migration window
```

#### 2. Rotate SECRET_KEY_BASE

**⚠️ WARNING**: This will invalidate ALL Phoenix sessions and tokens.

```bash
# Generate new secret
mix phx.gen.secret

# Update environment variable
export SECRET_KEY_BASE="new_secret_key_base_here"

# Option A: Graceful migration (recommended)
# 1. Deploy new SECRET_KEY_BASE
# 2. Revoke all user tokens programmatically
# 3. Users will be forced to re-login

# Option B: Immediate (nuclear option)
# Simply restart with new SECRET_KEY_BASE
# All users logged out immediately
```

#### 3. Database Cleanup

After rotation, clean up old tokens:

```elixir
# In IEx console
Shadowfax.Accounts.revoke_all_user_tokens(user_id, "security_rotation")
Shadowfax.Accounts.delete_expired_tokens()
Shadowfax.Accounts.clean_expired_blacklist()
```

### Gradual Token Migration

Support multiple token versions during rotation:

```elixir
# Current implementation supports token_version field
# To migrate:
# 1. Set TOKEN_VERSION=2
# 2. New tokens issued with version 2
# 3. Old tokens (version 1) still valid
# 4. After migration period, revoke version 1 tokens
```

---

## Token Blacklisting

### How It Works

When a token is revoked:
1. Token hash added to `token_blacklist` table
2. Token deleted from `auth_tokens` table
3. Future requests with that token are rejected

### Blacklist Use Cases

- **User Logout**: Single token revocation
- **Logout All Devices**: Revoke all user tokens
- **Security Incident**: Emergency token revocation
- **Password Change**: Auto-revoke all existing tokens

### API Endpoints

```bash
# Logout (revoke current token)
DELETE /api/auth/logout

# Logout all devices
DELETE /api/auth/logout?logout_all=true

# List active sessions
GET /api/auth/sessions

# Revoke specific session
DELETE /api/auth/sessions/:id
```

---

## Environment Configuration

### Required Environment Variables (Production)

```bash
# Database
DATABASE_URL=ecto://user:pass@host/database

# Phoenix
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
PHX_HOST=your-domain.com
PORT=4000

# Token Security
TOKEN_SALT=<generate with: mix phx.gen.secret>
TOKEN_VERSION=1
```

### Development Environment

```bash
# Optional overrides (defaults provided in config/dev.exs)
export SECRET_KEY_BASE="your_dev_secret"
export TOKEN_SALT="your_dev_salt"
export DATABASE_USERNAME="postgres"
export DATABASE_PASSWORD="postgres"
```

### Testing Environment

No environment variables needed - defaults in `config/test.exs` are secure for testing.

---

## Emergency Procedures

### 🚨 Security Breach Response

#### Immediate Actions (0-5 minutes)

```bash
# 1. Revoke ALL tokens immediately
iex -S mix
Shadowfax.Repo.transaction(fn ->
  Shadowfax.Repo.delete_all(Shadowfax.Accounts.AuthToken)
end)

# 2. Rotate secrets
export TOKEN_VERSION=$((TOKEN_VERSION + 1))
export TOKEN_SALT=$(mix phx.gen.secret)
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# 3. Restart application
# All users will be logged out
```

#### Follow-up Actions (5-30 minutes)

1. **Investigate**: Check logs for suspicious activity
2. **Notify**: Inform affected users
3. **Document**: Record incident details
4. **Review**: Audit access controls

### 🔧 Token System Issues

#### Problem: Users can't authenticate

```elixir
# Check database connectivity
Shadowfax.Repo.query!("SELECT 1")

# Check for expired tokens causing issues
Shadowfax.Accounts.delete_expired_tokens()

# Verify blacklist isn't blocking legitimate tokens
Shadowfax.Accounts.clean_expired_blacklist()
```

#### Problem: Token generation failing

```elixir
# Verify configuration
Application.get_env(:shadowfax, :token_salt)
Application.get_env(:shadowfax, :token_version)

# Check database can accept new tokens
Shadowfax.Accounts.create_auth_token(%{
  user_id: 1,
  token_hash: "test_hash",
  token_type: "access",
  token_version: 1,
  expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
})
```

---

## Maintenance Tasks

### Scheduled Cleanup (Run Daily)

```elixir
# Add to a scheduler (e.g., Quantum, Oban)
defmodule Shadowfax.Scheduler do
  def daily_token_cleanup do
    # Remove expired tokens
    {count, _} = Shadowfax.Accounts.delete_expired_tokens()
    IO.puts("Deleted #{count} expired tokens")

    # Clean expired blacklist entries
    {count, _} = Shadowfax.Accounts.clean_expired_blacklist()
    IO.puts("Cleaned #{count} blacklist entries")
  end
end
```

### Manual Cleanup Commands

```bash
# Production console
iex -S mix

# Delete expired tokens
Shadowfax.Accounts.delete_expired_tokens()

# Clean blacklist
Shadowfax.Accounts.clean_expired_blacklist()

# List user sessions
Shadowfax.Accounts.list_user_tokens(user_id)

# Revoke all tokens for compromised user
Shadowfax.Accounts.revoke_all_user_tokens(user_id, "security_incident")
```

### Database Monitoring

Monitor these metrics:
- `auth_tokens` table size (should stay bounded)
- `token_blacklist` table size (grows over time, needs cleanup)
- Token creation rate (detect anomalies)
- Failed authentication attempts (potential attacks)

---

## Best Practices

### For Developers

1. **Never commit secrets** to version control
2. **Use environment variables** for all sensitive config
3. **Rotate secrets regularly** (90 day cycle)
4. **Test token expiration** in development
5. **Monitor authentication failures** for attacks
6. **Document security changes** in this file

### For Operations

1. **Automate secret rotation** (CI/CD pipeline)
2. **Backup blacklist table** before cleanup
3. **Monitor token table growth** (set alerts)
4. **Log security events** to SIEM
5. **Schedule regular cleanups** (daily)
6. **Test disaster recovery** procedures

### For Security

1. **Access tokens**: Keep TTL short (15 min max)
2. **Refresh tokens**: Rotate on use (current implementation)
3. **Token storage**: Always hash before storing
4. **Blacklist**: Required for revocation
5. **Version field**: Enables gradual migration
6. **Device tracking**: Helps detect anomalies

### Token TTL Recommendations

| Token Type | TTL | Rationale |
|------------|-----|-----------|
| Access | 15 min | Limits exposure window |
| Refresh | 30 days | Balance security/UX |
| Remember me | 90 days | Optional, higher risk |

---

## Security Checklist

### Pre-Deployment

- [ ] All secrets in environment variables
- [ ] TOKEN_SALT is unique per environment
- [ ] SECRET_KEY_BASE is strong (64+ chars)
- [ ] Database backups configured
- [ ] Monitoring/alerting set up
- [ ] HTTPS/TLS enforced

### Post-Deployment

- [ ] Verify token creation works
- [ ] Test token refresh flow
- [ ] Confirm logout blacklists tokens
- [ ] Check database indexes exist
- [ ] Monitor initial performance
- [ ] Schedule cleanup tasks

### Regular Audits (Monthly)

- [ ] Review authentication logs
- [ ] Check for expired tokens in DB
- [ ] Verify blacklist cleanup running
- [ ] Test token rotation procedure
- [ ] Update this documentation
- [ ] Review user session counts

---

## Troubleshooting

### Common Issues

#### "Token has been revoked"
- Check if token is in blacklist table
- User may have logged out
- Token may have been manually revoked

#### "Token has expired"
- Access token expired (expected after 15 min)
- Client should use refresh token
- Check client refresh logic

#### "Invalid token"
- Token not in database
- Wrong token type (access vs refresh)
- Database connection issue
- Token hash mismatch

#### "Authentication failed"
- Generic error (check logs)
- Possible token tampering
- Database query failure

### Debug Commands

```elixir
# Check if token exists
token_hash = Shadowfax.Accounts.AuthToken.hash_token("your_token")
Shadowfax.Accounts.get_auth_token_by_hash(token_hash)

# Check if token is blacklisted
Shadowfax.Accounts.token_blacklisted?(token_hash)

# Verify token manually
Shadowfax.Accounts.verify_token("your_token", "access")
```

---

## Contact & Support

For security issues:
- **Email**: security@shadowfax.example.com
- **Emergency**: [On-call rotation]
- **Documentation**: This file (SAFETY.md)

For questions about this guide, contact the security team or open an issue in the project repository.

---

**Last Updated**: 2025-10-03
**Next Review**: 2026-01-03 (Quarterly)
