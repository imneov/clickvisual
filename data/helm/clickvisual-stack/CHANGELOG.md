# Changelog

All notable changes to the ClickVisual Stack Helm Chart will be documented in this file.

## [1.0.0] - 2025-12-27

### Added
- Initial release of ClickVisual Stack Helm Chart
- Complete umbrella chart with all dependencies
- Smart dependency management (auto-deploy or use external services)
- Support for two deployment modes:
  - Standalone mode: Auto-deploy MySQL, Redis, ClickHouse, Kafka, Zookeeper
  - External mode: Connect to existing external services
- Components included:
  - ClickVisual web application
  - MySQL for metadata storage
  - Redis for session cache
  - ClickHouse for log data storage
  - Kafka for message queue
  - Zookeeper for Kafka coordination
  - Fluent-bit for log collection (DaemonSet)
  - Prometheus & AlertManager (optional)
- Helper templates for automatic connection string generation
- Three example configurations:
  - minimal-values.yaml: For development/testing (low resources)
  - production-values.yaml: For production (high availability)
  - external-services-values.yaml: Using external services
- Installation script for easy deployment
- Comprehensive documentation:
  - README.md: Full documentation
  - QUICKSTART.md: 5-minute quick start guide
- Ingress support with TLS
- ConfigMap-based configuration
- Init containers for dependency checking
- RBAC for Fluent-bit
- Resource limits and requests for all components
- Persistent volume support for all stateful components

### Features
- Conditional deployment based on values
- Auto-generated connection strings
- Support for custom StorageClass
- OAuth integration (GitHub, GitLab)
- Multi-replica support with Redis
- Configurable resources for all components
- Helm hooks for proper startup order

### Documentation
- Detailed README with all configuration options
- Quick start guide for rapid deployment
- Production deployment best practices
- Troubleshooting guide
- Backup and restore procedures
- Upgrade instructions

[1.0.0]: https://github.com/clickvisual/clickvisual/releases/tag/helm-v1.0.0
