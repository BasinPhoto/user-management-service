# Vapor Authentication Template
[![Swift 5.9](https://img.shields.io/badge/swift-5.9-orange.svg?style=flat)](http://swift.org)
[![Vapor 4](https://img.shields.io/badge/vapor-4.0-blue.svg?style=flat)](https://vapor.codes)

This package is a Vapor 4 template to showcase different features and include authentication functions needed for a lot of apps. It uses concepts such as: repository pattern, queues, jwt, fluent, testing and mailgun

The template can be cloned and configured/changed to fit your needs, but should give a good starting point to anyone new to Vapor.

## Features
* User registration
* User login
* Reset password
* Email verification
* Refresh and access tokens
* Testing
* JWT Authentication
* Queues for email sending
* Repository Pattern
* Mailgun

## Routes
| URL                            | HTTP Method | Description                                              | Content (Body)          |
|--------------------------------|:-----------:|----------------------------------------------------------|-------------------------|
| /v1/auth/register              |     POST    | Registers a user and sends email verification            | `RegisterRequest`       |
| /v1/auth/login                 |     POST    | Login with existing user (requires email verification)   | `LoginRequest`          |
| /v1/auth/email-verification    |     GET     | Used to verify an email with a email verification token  | Query parameter `token` |
| /v1/auth/email-verification    |     POST    | (Re)sends email verification to a specific email         | `SendEmailVerification` |
| /v1/auth/reset-password        |     POST    | Sends reset-password email with token                    | `ResetPasswordRequest`  |
| /v1/auth/reset-password/verify |     GET     | Verifies a given reset-password token                    | Query parameter `token` |
| /v1/auth/recover               |     POST    | Changes user password with reset-password token supplied | `RecoverAccountRequest` |
| /v1/auth/me                    |     GET     | Returns the current authenticated user                   | None                    |
| /v1/auth/accessToken           |     POST    | Gives the user a new accesstoken and refresh token       | `AccessTokenRequest`    |

## Configuration
### Environment variables
These environment variables will be used for configuring different services by default:
| Key                 | Default Value            | Description                                                                                         |
|---------------------|--------------------------|-----------------------------------------------------------------------------------------------------|
| `POSTGRES_HOSTNAME` | `localhost`              | Postgres hostname                                                                                   |
| `POSTGRES_USERNAME` | `vapor`                  | Postgres usernane                                                                                   |
| `POSTGRES_PASSWORD` | `password`               | Postgres password                                                                                   |
| `POSTGRES_DATABASE` | `vapor`                  | Postgres database                                                                                   |
| `JWKS_KEYPAIR_FILE` | `keypair.jwks`           | JWKS Keypair file relative to root directory see "JWT" section for more info                        |
| `MAILGUN_API_KEY`   | None                     | Mailgun API Key                                                                                     |
| `SITE_API_URL`      | None                     | The URL where your API will be hosted ex: "https://api.myapp.com" (used for email-verification URL) |
| `SITE_FRONTEND_URL` | None                     | The URL where your frontend will be hosted ex: "http://myapp.com" (used for reset-password URL)     |
| `NO_REPLY_EMAIL`    | None                     | The no reply email that will be used for Mailgun                                                    |
| `REDIS_URL`         | `redis://127.0.0.1:6379` | Redis URL for Queues worker.                                                                        |
### App config
`AppConfig` contains configuration like API URL, frontend URL and no-reply email. It loads from environment variables by default. Otherwise you can override it inside `configure.swift`:
```swift
app.config = .init(...)
```

### Constants
`Constants.swift` contains constants releated to tokens lifetime.
| Token                    | Lifetime   |
|--------------------------|------------|
| Access Token             | 15 minutes |
| Refresh Token            | 7 days     |
| Email Verification Token | 24 hours   |
| Reset Password Token     | 1 hour     |

### Mailgun
The template uses [VaporMailgunService](https://github.com/vapor-community/VaporMailgunService) and be configured as it states in the documentation. `Extensions/Mailgun+Domains.swift` contains the domains.

### JWT
This package uses JWT for Access Tokens, and by default it loads JWT credentials from a JWKS file called `keypair.jwks` in the root directory. You can generate a JWKS keypair at https://mkjwk.org/

##Testing

###Database
For testing start docker container with following settings:

```
docker run --name postgres-test -e POSTGRES_DB=vapor-test \
  -e POSTGRES_USER=vapor_username -e POSTGRES_PASSWORD=vapor_password \
  -p 5433:5432 -d postgres
```
