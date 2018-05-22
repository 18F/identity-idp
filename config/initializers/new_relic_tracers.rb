## Add NR tracers to methods so we can trace execution in the NR dashboard
## Ref: https://docs.newrelic.com/docs/agents/ruby-agent/api-guides/ruby-custom-instrumentation
require 'new_relic/agent/method_tracer'
require 'aws/ses'

Aws::SES::Base.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/initialize"
  add_method_tracer :deliver, "Custom/#{name}/deliver"
  add_method_tracer :deliver!, "Custom/#{name}/deliver!"
  add_method_tracer :ses_client, "Custom/#{name}/ses_client"
end

ConfirmationEmailPresenter.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/initialize"
  add_method_tracer :first_sentence, "Custom/#{name}/first_sentence"
  add_method_tracer :confirmation_period, "Custom/#{name}/confirmation_period"
end

CustomDeviseMailer.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/initialize"
  add_method_tracer :confirmation_instructions, "Custom/#{name}/confirmation_instructions"
  add_method_tracer :initialize_from_record, "Custom/#{name}/initialize_from_record"
  add_method_tracer :mail, "Custom/#{name}/mail"
end

Mail::Message.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/initialize"
  add_method_tracer :deliver, "Custom/#{name}/deliver"
  add_method_tracer :deliver!, "Custom/#{name}/deliver!"
end

User.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :send_devise_notification, "Custom/#{name}/send_devise_notification"
  add_method_tracer(
    :send_custom_confirmation_instructions, "Custom/#{name}/send_custom_confirmation_instructions"
  )
end

Encryption::UserAccessKey.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/build"
end
