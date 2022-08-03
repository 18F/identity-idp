# Back-end archictecture

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

At the end of the day, analytics events get dumped into `events.log` and contain
information like user ID, service provider, user agent, etc.

Event names are strings. Events correspond to methods in the
[AnalyticsEvents](../app/services/analytics_events.rb) mixin. We document these
with YARD so that we can auto-generate
[documentation on them in our handbook][analytics-handbook]

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
