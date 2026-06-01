# SQL Injection Fix Plan

**Date:** 2026-06-01
**Status:** Completed
**Severity:** Critical

## Executive Summary

A SQL injection vulnerability was identified in `app/services/deleted_accounts_report.rb`. The vulnerability has been fixed by replacing unsafe string formatting with Rails' parameterized query methods.

## Vulnerability Description

### Location

- **File:** `app/services/deleted_accounts_report.rb`
- **Lines:** 10-14 (original)
- **Method:** `DeletedAccountsReport.call`

### Issue

The original code used Ruby's `format()` method with `%s` placeholders to construct a SQL query:

```ruby
report_sql = <<~SQL
  SELECT last_authenticated_at, identity_uuid FROM
  (SELECT ids.last_authenticated_at AS last_authenticated_at,
          ids.uuid AS identity_uuid, us.id AS users_id
  FROM identities AS ids LEFT JOIN users AS us ON ids.user_id=us.id
  WHERE service_provider='%s' AND last_authenticated_at > '%s') AS tbl
  WHERE users_id IS NULL ORDER BY last_authenticated_at ASC
SQL
sql = format(report_sql, service_provider, days_ago.to_i.days.ago)
ActiveRecord::Base.connection.execute(sql)
```

The `service_provider` parameter was inserted directly into the SQL string without sanitization, making the code vulnerable to SQL injection attacks.

### Risk Assessment

| Factor | Assessment |
|--------|------------|
| **Attack Vector** | Network (if `service_provider` comes from user input) |
| **Complexity** | Low |
| **Privileges Required** | Depends on call context |
| **Impact** | High (potential data breach, data manipulation, or deletion) |

**Example Attack:**
An attacker could pass a malicious `service_provider` value such as:
```
'; DROP TABLE users; --
```

This would result in the following SQL being executed:
```sql
SELECT ... WHERE service_provider=''; DROP TABLE users; --' AND ...
```

## Fix Implementation

### Solution

Replace the unsafe `format()` call with `ApplicationRecord.sanitize_sql_array()` using named parameters:

```ruby
report_sql = <<~SQL
  SELECT last_authenticated_at, identity_uuid FROM
  (SELECT ids.last_authenticated_at AS last_authenticated_at,
          ids.uuid AS identity_uuid, us.id AS users_id
  FROM identities AS ids LEFT JOIN users AS us ON ids.user_id=us.id
  WHERE service_provider = :service_provider AND last_authenticated_at > :cutoff_time) AS tbl
  WHERE users_id IS NULL ORDER BY last_authenticated_at ASC
SQL
sql = ApplicationRecord.sanitize_sql_array(
  [report_sql, { service_provider: service_provider, cutoff_time: days_ago.to_i.days.ago }],
)
ActiveRecord::Base.connection.execute(sql)
```

### Why This Approach

1. **Consistent with codebase patterns:** Other files in this codebase (e.g., `app/models/user.rb`, `lib/data_pull.rb`) use `sanitize_sql_array` for raw SQL
2. **Named parameters:** Improves readability and maintainability over positional placeholders
3. **Proper escaping:** Rails automatically escapes special characters in parameter values
4. **Type safety:** Handles different data types (strings, timestamps) correctly

## Testing

### Regression Test Added

A new test case was added to `spec/services/deleted_accounts_report_spec.rb`:

```ruby
it 'safely handles service_provider values with SQL injection attempts' do
  malicious_sp = "'; DROP TABLE users; --"

  # Should not raise an error and should return empty results
  expect { DeletedAccountsReport.call(malicious_sp, days_ago) }.not_to raise_error

  rows = DeletedAccountsReport.call(malicious_sp, days_ago)
  expect(rows.count).to eq(0)

  # Verify the users table still exists and is accessible
  expect { User.count }.not_to raise_error
end
```

### Test Verification

Run the specific test file:
```bash
bundle exec rspec spec/services/deleted_accounts_report_spec.rb
```

## Codebase Analysis Summary

### Other Raw SQL Usage (Properly Sanitized)

The following files were reviewed and found to use proper sanitization:

| File | Sanitization Method | Status |
|------|---------------------|--------|
| `app/models/user.rb` | `sanitize_sql_array` | Safe |
| `app/services/backup_code_generator.rb` | `sanitize_sql_array` | Safe |
| `app/services/verification_failures_report.rb` | `connection.quote` | Safe |
| `app/jobs/reports/*.rb` | `QueryHelpers#quote` | Safe |
| `lib/data_pull.rb` | `sanitize_sql_array` | Safe |
| `app/services/db/identity/sp_user_counts.rb` | `sanitize_sql_array` | Safe |

### Recommended Patterns for Future Development

When writing raw SQL queries in this codebase, use one of these approved patterns:

**Pattern 1: `sanitize_sql_array` with named parameters (preferred)**
```ruby
sql = ApplicationRecord.sanitize_sql_array(
  [query_template, { param1: value1, param2: value2 }]
)
ActiveRecord::Base.connection.execute(sql)
```

**Pattern 2: `connection.quote` for individual values**
```ruby
quoted_value = ActiveRecord::Base.connection.quote(user_input)
sql = "SELECT * FROM table WHERE column = #{quoted_value}"
```

**Pattern 3: Use `QueryHelpers#quote` (for report jobs)**
```ruby
include QueryHelpers

def params
  { start_date: quote(start_date), end_date: quote(end_date) }
end
```

## References

- [Rails SQL Injection Guide](https://guides.rubyonrails.org/security.html#sql-injection)
- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- NIST SP 800-53: SI-10 (Information Input Validation)
