Hi! Before submitting your PR for review, and/or before merging it, please
go through the checklists below. These represent the more critical elements
of our code quality guidelines. The rest of the list can be found in
[CONTRIBUTING.md]

[CONTRIBUTING.md]: https://github.com/18F/identity-idp/blob/master/CONTRIBUTING.md#pull-request-guidelines

### Controllers

- [ ] When adding a new controller that requires the user to be fully
authenticated, make sure to add `before_action :confirm_two_factor_authenticated`
as the first callback.

### Database

- [ ] Unsafe migrations are implemented over several PRs and over several
deploys to avoid production errors. The [strong_migrations](https://github.com/ankane/strong_migrations#the-zero-downtime-way) gem
will warn you about unsafe migrations and has great step-by-step instructions
for various scenarios.

- [ ] Indexes were added if necessary. This article provides a good overview
of [indexes in Rails](https://semaphoreci.com/blog/2017/05/09/faster-rails-is-your-database-properly-indexed.html).

- [ ] Verified that the changes don't affect other apps (such as the dashboard)

- [ ] When relevant, a rake task is created to populate the necessary DB columns
in the various environments right before deploying, taking into account the users
who might not have interacted with this column yet (such as users who have not
set a password yet)

- [ ] Migrations against existing tables have been tested against a copy of the
production database. See #2127 for an example when a migration caused deployment
issues. In that case, all the migration did was add a new column and an index to
the Users table, which might seem innocuous.

### Encryption

- [ ] The changes are compatible with data that was encrypted with the old code.

### Routes

- [ ] GET requests are not vulnerable to CSRF attacks (i.e. they don't change
state or result in destructive behavior).

### Session

- [ ] When adding user data to the session, use the `user_session` helper
instead of the `session` helper so the data does not persist beyond the user's
session.

### Testing

- [ ] Tests added for this feature/bug
- [ ] Prefer feature/integration specs over controller specs
- [ ] When adding code that reads data, write tests for nil values, empty strings,
and invalid inputs.
