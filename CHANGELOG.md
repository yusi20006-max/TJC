# Changelog

## 1.0.0
- Production Readiness Audit completed, ensuring 100% production-readiness.
- High-performance, daemonless design with non-daemon Scheduler System running via a 'run-pending' pull model.
- Decoupled Workflow Engine supporting YAML/JSON execution plans, sequential steps, and detailed report tracking.
- Secure design with API secret masking, strict validation of alphanumeric and file path patterns to prevent command injection, and secure folder permissions (700 and 600).
- Standardized Shell/POSIX shared libraries (`lib/`) for config, logging, terminal colors, and checks.
- Comprehensive POSIX testing harness with automated suites (`test_workflows.sh` and `test_scheduler.sh`) running in isolated environments.
- 100% ShellCheck compliance across all project scripts.
- Exhaustive documentation updates including new manuals for installation, testing, development, workflows, scheduler, and plugins.

## 0.1.0-dev
- Initial bootstrap structure
- CLI entrypoint and basic commands
- Install and uninstall scripts
- Base documentation and CI shellcheck workflow
