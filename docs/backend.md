# Back-end Architecture

The IDP is a Rails application, that follows many typical Rails conventions.

## Networking

For consistency, we use [Faraday](https://github.com/lostisland/faraday)
when making HTTP requests. We also wire in notifications so we can
[log metrics on these requests](../config/initializers/faraday.rb)

```ruby
# request_metric is logged specifically as a metric to allow for quicker data aggregation and
# historical querying
conn = Faraday.new do |f|
  f.request :instrumentation, name: 'request_metric.faraday'
end

# request_log is logged, but only to the log file, typically for requests where we are
# less interested in aggregation and generally only need to view the attributes of a specific
# request
conn = Faraday.new do |f|
  f.request :instrumentation, name: 'request_log.faraday'
end

# service_name is a required context attribute and is the unique identifier for the request.
# Requests within the same service (e.g. a POST, GET, etc. to different resources) should have a
# distinct service_name.
resp = conn.post do |req|
  req.options.context = { service_name: 'aamva_token' }
end
```

## Forms, FormResponse, Analytics, and Controllers

We aim to keep Controllers simple and lean, and put business logic in Form
classes, and hand those results (FormResponse) to our Analytics class to get
logged in a consistent way.

For details on frontend form behaviors, refer to the [equivalent section of the Front-end Architecture document](./frontend.md#forms).

### FormResponse

The [FormResponse](../app/services/form_response.rb) is a simple structure to help
bundle up properties for logging. **Do not put PII or sensitive information
inside these** because they are intended to be logged.

```ruby
FormResponse.new(
  success: true | false,
  errors: Hash | ActiveModel::Errors,
  extra: Hash,
)
```

### Forms

We use `ActiveModel::Model` validations to help build useful error structures.

Forms should have a `#submit` method that returns a `FormResponse`.
- `success:` is usually `#valid?` from ActiveModel
- `errors:` is usually `#errors` from ActiveModel
- `extra:` is, by convention, a method called `extra_analytics_attributes` that
  returns a Hash

```ruby
def submit
  FormResponse.new(
    success: valid?,
    errors: errors,
    extra: extra_analytics_attributes,
  )
end
```

For sensitive properties, or results that are not meant to be logged, add
properties to the Form object that get written during `#submit`

### Analytics

Analytics events are appended to `log/events.log` and contain information both common information as
well as custom event properties. Common information includes service provider, user ID, browser
details, and other information.

Event names correspond to methods in the [AnalyticsEvents](../app/services/analytics_events.rb)
mixin. We document these with YARD so that we can auto-generate
[documentation on them in our handbook][analytics-handbook].

> [!NOTE]
> The convention to name events to match the method name is expected for all new analytics events,
> but you will find a number of exceptions for analytics which had existed prior to this convention
> being established.

If you are adding or troubleshooting events, consider running the `watch_events` Makefile target in
a separate terminal. This command will print formatted event data as it happens, so you can see what
events are logged as you navigate the application in your local development environment.

```
make watch_events
```

You can also watch for specific events by assigning the `EVENT_NAME` environment variable:

```
EVENT_NAME="piv_cac_disabled" make watch_events
```

[analytics-handbook]: https://handbook.login.gov/articles/analytics-events.html

### Controllers

These tie everything together! We aim for lean, "RESTful" controllers

* Keep as much business logic as possible out of controllers moving that logic
  into Forms or Services

* Prefer adding a new controller with one of the CRUD methods over creating a
  custom method in an existing controller. For example, if your app allows a
  user to update their email and their password on two different pages, instead of
  using a single controller with methods called `update_email` and
  `update_password`, create two controllers and name the methods `update`, i.e.
  `EmailsController#update` and `PasswordsController#update`. See
  http://jeromedalbert.com/how-dhh-organizes-his-rails-controllers/ for more about
  this design pattern.


```ruby
class MyController < ApplicationController
  def update
    form = MyForm.new(params)

    result = form.submit
    analytics.my_event(**result.to_h)

    if result.success?
      do_something(form.sensitive_value_here)
    else
      do_something_else
    end
  end
end
```

## Database

We make use of ActiveRecord for our ORM. It is important to remain mindful of what your
code is doing to prevent unnecessary queries. For example, the following conditional
should be rearranged:

```ruby
# Bad: potentially-unnecessary DB query
if mfa_user.two_factor_enabled? && !in_mfa_selection_flow
  # ...
end
```

`mfa_user.two_factor_enabled?` will trigger a database query, while
`in_mfa_selection_flow` is a variable already in memory. Therefore, rearranging the
conditional to check the local variable first can save an unnecessary database query:

```ruby
# Good: avoids potentially-unnecessary DB query
if !in_mfa_selection_flow && mfa_user.two_factor_enabled?
  # ...
end
```

### Eager loading

In this example, the concern is specifically that the `two_factor_enabled?` method 
issues a database query, fetching an association.

An alternative approach to consider when dealing with associations is to make use
of [eager loading](https://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations),
which could allow fetching the associated records with a join in the same query.
