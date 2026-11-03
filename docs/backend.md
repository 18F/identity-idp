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

By including `ActiveModel::Model`, you can use any of [Rails' built-in model validation helpers](https://guides.rubyonrails.org/active_record_validations.html#validation-helpers)
or define [custom validation logic](https://guides.rubyonrails.org/active_record_validations.html#custom-methods).
Regardless how you validate, you should use human-readable error messages and associate the error to
the specific form parameter field that it affects, if the form is responsible for validating input
from a page.

```rb
class NewEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validates_presence_of :email, { message: proc { I18n.t('errors.email.blank')} }
  validate :validate_banned_email

  def submit(email:)
    @email = email

    FormResponse.new(success: valid?, errors:, extra: extra_analytics_attributes)
  end

  def validate_banned_email
    return if !BannedEmail.find_by(email: @email)
    errors.add(:email, :banned, message: t('errors.email.banned'))
  end

  # ...
end
```

For sensitive properties, or results that are not meant to be logged, add
properties to the Form object that get written during `#submit`

### Form Error Handling

If form validation is unsuccessful, you should inform the user what needs to be done to correct the
issue by one or both of the following:

- Flash message
- Inline field errors

For convenience, a `FormResponse` object includes a `first_error_message` method which can be used
if you want to display a single error message, such as in a flash banner.

```rb
result = @form.submit(**params)
if result.success?
  # ...
else
  flash.now[:error] = result.first_error_message
  render :new
end
```

In the view, a [SimpleForm](https://github.com/heartcombo/simple_form) form can be bound to a form
object. By doing so, each error will automatically be shown with the corresponding page input.

```erb
<%= simple_form_for @form, url: emails_path do |f| %>
  <%= render ValidatedFieldComponent.new(form: f, name: :email) %>
<% end >
```

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
    analytics.my_event(**result)

    if result.success?
      do_something(form.sensitive_value_here)
    else
      do_something_else
    end
  end
end
```
