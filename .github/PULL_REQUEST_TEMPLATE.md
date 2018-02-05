Hi! Before submitting your PR for review, and/or before merging it, please
go through the following checklist:

- [ ] For DB changes, check for missing indexes, check to see if the changes
affect other apps (such as the dashboard), make sure the DB columns in the
various environments are properly populated, coordinate with devops, plan
migrations in separate steps.

- [ ] For route changes, make sure GET requests don't change state or result in
destructive behavior. GET requests should only result in information being
read, not written.

- [ ] For encryption changes, make sure it is compatible with data that was
encrypted with the old code.

- [ ] Do not disable Rubocop or Reek offenses unless you are absolutely sure
they are false positives. If you're not sure how to fix the offense, please
ask a teammate.

- [ ] When reading data, write tests for nil values, empty strings,
and invalid formats.

- [ ] When calling `redirect_to` in a controller, use `_url`, not `_path`.

- [ ] When adding user data to the session, use the `user_session` helper
instead of the `session` helper so the data does not persist beyond the user's
session.

- [ ] When adding a new controller that requires the user to be fully
authenticated, make sure to add `before_action :confirm_two_factor_authenticated`.
