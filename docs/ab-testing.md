# A/B Testing

Testing new features or feature variations on a subset of users allows us to make data-informed
decisions. Support for A/B testing is available through the [`AbTest` class][ab-test-class].
Ongoing experiments are configured in the [A/B test initializer configuration][ab-test-configs].

[ab-test-class]: https://github.com/18F/identity-idp/blob/main/lib/ab_test.rb
[ab-test-configs]: https://github.com/18F/identity-idp/blob/main/config/initializers/ab_tests.rb

## Example

The kitchen sink example below demonstrates all of the available options for a hypothetical A/B
test experimenting encouraging the adoption of a Face or Touch Unlock authentication method.

Normally, you'd want many of these values to be managed in [application config](https://handbook.login.gov/articles/appdev-secrets-configuration.html)
(e.g. bucket percentages, report email), but they are defined here as literal values for clarity.

```rb
ENCOURAGE_FACE_TOUCH_UNLOCK = AbTest.new(
  experiment_name: 'Encourage Face or Touch Unlock',
  should_log: [
    'Multi-Factor Authentication Setup',
  ].to_set,
  buckets: {
    emphasize_security: 1,
    emphasize_speed: 1,
  },
  default_bucket: :bucket,
  persist: true,
  max_participants: 10_000,
  report: {
    email: 'example@example.com',
    queries: [
      {
        title: 'Setup by variation',
        query: <<~QUERY,
          | fields (properties.event_properties.ab_tests.encourage_face_touch_unlock.bucket) as bucket
          | filter name = 'Multi-Factor Authentication Setup'
          | stats count(*) as `Setup Count` by bucket
          | sort bucket asc
        QUERY
        row_labels: ['Default', 'Emphasized Security', 'Emphasized Speed'],
      },
    ],
  },
) { |user:, **| user.uuid }.freeze
```

In this example, there are 3 variations:

- The default experience (control group)
- A variation emphasizing security, with the expectation that 1% of users would experience this
  variation
- A variation emphasizing speed, with the expectation that 1% of users would experience this
  variation

Assignments for this experiment are persisted to the database, and a maximum of 10,000 participants
can be included before the test is automatically disabled.

Analytics events for `'Multi-Factor Authentication Setup'` will be annotated with A/B test bucket
assignments for this experiment.

A daily report will be emailed to `example@example.com` including relevant analytics query results
for the past day of activity, and detailing the number of participants in the test.

## Options

### `experiment_name` (`String`)

A human-readable short description of the experiment.

### `should_log` (`Enumerable` or `Regexp` or `nil`)

A list of analytics event names for which the A/B test bucket assignment should be logged, or a
regular expression pattern which is tested against an analytics event name when an event is being
logged.

Defaults to `nil`.

### `default_bucket` (`Symbol`)

The bucket name that should be returned for a test candidate not selected for one of the listed
test alternatives, to be considered part of the control group.

Defaults to `:default`.

### `buckets` (`Hash<String, Integer>`)

The set of test variations for an experiment, with keys denoting the test name and the value a
percent of visitors who should be included in the test.

### `persist` (`Boolean`)

Whether the test assignment should be persisted to the database.

Defaults to `false`.

### `max_participants` (`Integer`)

The maximum number of participants allowed in the test. This option requires `persist` to be `true`.

Defaults to `Float::INFINITY`.

### `report` (`Hash`)

Report mailer configuration.

- `report[:email]`: The email address where the report should be delivered.
- `report[:queries]`: An array of individual report items.
   - `report[:queries][][:title]`: A human-readable label describing an individual report result.
   - `report[:queries][][:query]`: The query to generate the report result.
   - `report[:queries][][:row_labels]`: Optional human-readable labels to use in place of the first
     column results.

### `&block`

A block passed when initializing an instance of `AbTest` will be used to generate a value to
deterministically seed bucket assignment for a visitor.

The block will receive a hash of parameters with the following properties:

- `request`: The current request object
- `service_provider`: The current service provider's issuer string
- `session`: The session object
- `user`: The current user (if signed-in)
- `user_session`: The user session object

By default, an A/B test will use the currently logged-in user's UUID.
