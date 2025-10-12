# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Build and Test
- `mix setup` - Initialize development environment (get deps and compile)
- `mix compile` - Compile the project (with warnings as errors)
- `mix test` - Run the test suite
- `mix test.watch` - Run tests in watch mode
- `make build` - Compile with warnings as errors (via Makefile)

### Code Quality
- `mix format` - Format code automatically
- `mix format --check-formatted` - Check if code is properly formatted
- `mix credo` - Run static code analysis
- `mix dialyzer` - Run type checking
- `make lint` - Check code formatting (via Makefile)

### Documentation
- `mix docs` - Generate documentation with ExDoc
- `mix hex.publish` - Publish package to Hex.pm

### Dependencies
- `mix deps.get` - Get all dependencies
- `mix deps.update --all` - Update all dependencies
- `mix deps.clean --unused` - Clean unused dependencies
- `mix deps.tree` - Show dependency tree

### Development Tools
- `iex -S mix` - Start interactive REPL
- `make repl` - Start interactive REPL (via Makefile)

## Architecture Overview

### Core Module Structure
The SDK follows a modular architecture with clear separation of concerns:

- **ExWechatpay** - Main public interface using macro that delegates to Core
- **ExWechatpay.Core** - Central coordinator that manages config and delegates to service modules
- **ExWechatpay.Supervisor** - OTP supervisor managing Finch, Config.Manager, and Core processes
- **ExWechatpay.Typespecs** - Comprehensive type definitions for all API structures

### Configuration System
Configuration flows through several layers:
1. **ExWechatpay.Config.Provider** - Loads and validates initial configuration
2. **ExWechatpay.Config.Manager** - Runtime configuration management with certificate auto-update
3. **ExWechatpay.Config.Helper** - Public helper functions for config operations
4. **ExWechatpay.Config.Schema** - Configuration schema and validation rules

### Core Components
- **ExWechatpay.Core.RequestBuilder** - Constructs HTTP requests with proper authentication
- **ExWechatpay.Core.ResponseHandler** - Processes HTTP responses and decrypts encrypted data
- **ExWechatpay.Core.SignatureManager** - Handles request/response signature verification
- **ExWechatpay.Core.CertificateManager** - Manages WeChat platform certificates and auto-updates

### Service Layer
- **ExWechatpay.Service.Transaction** - All payment transaction operations (create, query, close)
- **ExWechatpay.Service.Refund** - All refund operations (create, query, notifications)

### HTTP Client
- **ExWechatpay.Http** - HTTP client behavior definition
- **ExWechatpay.Http.Finch** - Finch-based HTTP client implementation
- **ExWechatpay.Model.Http** - HTTP request/response models

### Key Design Patterns
1. **OTP Supervision** - Uses OTP principles with Supervisor/Core/Agent pattern
2. **Configuration as Data** - Configuration is immutable data stored in Agent
3. **Module Delegation** - Public interface delegates to specialized service modules
4. **Result Tuples** - Consistent `{:ok, result}` | `{:error, exception}` return pattern
5. **Type Safety** - Comprehensive type specifications throughout the codebase

### Configuration Requirements
The SDK requires these essential configuration parameters:
- `appid` - WeChat App ID
- `mchid` - Merchant ID
- `notify_url` - HTTPS callback URL
- `apiv3_key` - API v3 key for decryption
- `client_serial_no` - Merchant certificate serial number
- `client_key` - Merchant private key (PEM format)
- `client_cert` - Merchant certificate (PEM format)
- `wx_pubs` - WeChat platform certificates (list of {serial_no, cert} tuples)

### Testing Setup
Tests require environment variable `TEST_WECHAT_CERT_PATH` pointing to directory containing:
- `wx_pub.pem` - WeChat platform certificate
- `apiclient_key.pem` - Merchant private key
- `apiclient_cert.pem` - Merchant certificate

Test helper module: `ExWechatpay.Test.App` provides test client implementation.

### WeChat Pay API Integration
The SDK implements WeChat Pay API v3 with support for:
- **Native Pay** - QR code payments for PC/POS
- **JSAPI Pay** - In-app payments for WeChat Mini Programs/Official Accounts
- **H5 Pay** - Mobile web payments
- **Certificate Management** - Automatic platform certificate retrieval and updates
- **Webhook Verification** - Signature verification and notification decryption
- **Transaction Management** - Create, query, and close transactions
- **Refund Operations** - Create, query, and handle refund notifications

All API responses use string keys (not atoms) for consistency with WeChat Pay's JSON format.

## Project Information

- **Version**: 0.3.3
- **License**: MIT
- **Repository**: https://github.com/tt67wq/ex_wechatpay
- **Hex Package**: https://hex.pm/packages/ex_wechatpay
- **Documentation**: https://hexdocs.pm/ex_wechatpay
- **Description**: Elixir SDK for WeChat Pay API v3

## Key Dependencies

- **Finch** (~> 0.20) - HTTP client (optional, can provide custom implementation)
- **Jason** (~> 1.4) - JSON library (optional, can provide custom implementation)
- **NimbleOptions** (~> 1.1) - Configuration validation and schema
- **Credo** (~> 1.7) - Static code analysis (dev/test only)
- **Styler** (~> 0.11) - Code formatting (dev/test only)
- **Dialyxir** (~> 1.4) - Type checking (dev only)

## Advanced Architecture Patterns

### HTTP Client Abstraction
The SDK uses Finch as the default HTTP client but allows custom implementations through the `ExWechatpay.Http` behavior. HTTP requests are configured with:
- **Connection Pools**: Managed by Finch with configurable pool sizes
- **Timeouts**: Default 5000ms request timeout (configurable)
- **Retry Logic**: Optional retry mechanism with configurable attempts

### Type Safety and Error Handling
- **Comprehensive Typespecs**: All public functions have type specifications using `ExWechatpay.Typespecs`
- **Structured Exceptions**: `ExWechatpay.Exception` provides structured error types
- **Result Tuples**: Consistent `{:ok, result}` | `{:error, exception}` return pattern
- **Dialyxir Integration**: Static type checking for compile-time error detection

### Certificate Management
- **Auto-update Mechanism**: Platform certificates are automatically refreshed when expired
- **Certificate Validation**: Proper chain validation and expiration checking
- **Secure Storage**: Certificates stored in Agent with access through Config.Manager

### Security Implementation
- **Signature Verification**: RSA-SHA256 signatures for request/response authentication
- **Data Encryption**: AES-256-GCM for sensitive data encryption/decryption
- **Key Management**: Secure handling of merchant private keys and platform certificates

### Request/Response Flow
1. **ExWechatpay** macro delegates to **Core**
2. **Core** validates configuration and coordinates service modules
3. **RequestBuilder** constructs HTTP requests with proper headers and signatures
4. **HTTP Client** (Finch) sends requests to WeChat Pay API
5. **ResponseHandler** processes responses, validates signatures, and decrypts encrypted data
6. **Service Modules** return structured results to the caller

### Multi-merchant Support
The SDK supports multiple merchant configurations by creating separate client instances:
```elixir
defmodule MerchantA do
  use ExWechatpay, otp_app: :my_app, config_key: :merchant_a
end

defmodule MerchantB do
  use ExWechatpay, otp_app: :my_app, config_key: :merchant_b
end
```