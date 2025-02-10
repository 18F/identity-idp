# frozen_string_literal: true

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

Mail::Message.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/initialize"
  add_method_tracer :deliver, "Custom/#{name}/deliver"
  add_method_tracer :deliver!, "Custom/#{name}/deliver!"
end

SamlIdp::SignedInfoBuilder.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :encoded, "Custom/#{name}/encoded"
end
