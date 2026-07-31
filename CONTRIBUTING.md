# Contributing

## File ownership matrix
Each shared file has one owning issue that may restructure it. Other issues may only append new functions at the end and must not edit existing lines.

| File | Owning issue | Issues that may only append |
|---|---|---|
| lib/output.sh | 01 | 12 |
| lib/config.sh | 02 | 01 |
| lib/api.sh | 03 | 06,07,08,09,10 |
| lib/auth.sh | 04 | - |
| lib/logger.sh | 11 | 13 |
| lib/errors.sh | 13 | - |

## Rules
- Never commit secrets
- Keep shell scripts shellcheck-clean
- Do not modify a shared file you do not own except by appending a new function at the end
