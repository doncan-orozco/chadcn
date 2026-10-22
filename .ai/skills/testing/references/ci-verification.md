# CI/CD Verification Pipeline

## CI/CD Verification Pipeline

### What CI Checks On Every Push

When you push code to GitHub, the CI pipeline automatically runs:

#### 1. Security Scanning
```bash
bin/brakeman --no-pager          # Rails security vulnerabilities
bin/bundler-audit                 # Gem dependency vulnerabilities
bin/importmap audit               # JavaScript package vulnerabilities
```

**What it checks for:**
- SQL injection vulnerabilities
- Cross-site scripting (XSS) issues
- Unsafe mass assignment
- Hardcoded credentials
- Unsafe redirects/downloads
- Known vulnerabilities in gems and packages

#### 2. Code Quality (RuboCop)
```bash
bin/rubocop -f github
```

**What it checks:**
- Code style consistency
- Performance issues
- Rails best practices
- Minitest best practices
- Factory Bot patterns
- Capybara patterns

#### 3. Tests (Minitest)
```bash
rake test
```

**Runs all tests:**
- Unit tests (Models, Contracts, Operations)
- Integration tests (Controllers, Operations)
- System tests (User workflows with Playwright)

**Requirements:**
- All tests must pass
- New code must have tests
- No skipped tests (unless documented)

### Pre-Push Local Verification

Before pushing, run these checks locally:

```bash
# 1. Security checks (must pass)
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit

# 2. Code quality (must pass)
bin/rubocop --fix-layout   # Auto-fix what can be fixed
bin/rubocop                # Check remaining issues

# 3. Tests (must pass)
rake test                  # All tests

# 4. Only then push
git push
```

### Troubleshooting CI Failures

**Security failures:**
```bash
# Review issue
bin/brakeman --no-pager
# Fix vulnerability or update gems
bundle update vulnerable_gem
```

**RuboCop failures:**
```bash
# Auto-fix what can be fixed
bin/rubocop --fix-layout

# See remaining issues
bin/rubocop

# Check for common patterns
# → See skills/linting/references/lint-and-tests.md
```

**Test failures:**
```bash
# Run specific failing test
bin/rails test test/path/to_failing_test.rb -v

# Debug: check error message and stack trace
# → Verify fixtures and test setup
# → Check model/operation behavior
# → Reference test patterns in this skill
```

### CI Pipeline Order

```
Pull Request Created
  ↓
1. Security (Brakeman, Bundler-Audit, Importmap)
2. Code Quality (RuboCop)
3. Tests (Minitest)
  ↓
All Pass? → ✅ Ready to merge
Any Fail? → ❌ Fix locally, push again
```

### Checking CI Status

On GitHub:
1. Go to your **Pull Request**
2. Scroll to **Checks** section
3. View status of each job
4. Click to expand logs for details
