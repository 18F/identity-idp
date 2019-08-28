## Add NR tracers to methods so we can trace execution in the NR dashboard
## Ref: https://docs.newrelic.com/docs/agents/ruby-agent/api-guides/ruby-custom-instrumentation
require 'new_relic/agent/method_tracer'
require 'aws/ses'
require 'cloudhsm_jwt'

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

Mail::Message.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/initialize"
  add_method_tracer :deliver, "Custom/#{name}/deliver"
  add_method_tracer :deliver!, "Custom/#{name}/deliver!"
end

User.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :send_devise_notification, "Custom/#{name}/send_devise_notification"
end

SendSignUpEmailConfirmation.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer(
    :call, "Custom/#{name}/call"
  )
end

Encryption::UserAccessKey.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :initialize, "Custom/#{name}/build"
end

SamlIdp::SignedInfoBuilder.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :encoded, "Custom/#{name}/encoded"
  add_method_tracer :cloudhsm_encoded, "Custom/#{name}/cloudhsm_encoded"
end

CloudhsmJwt.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :encode, "Custom/#{name}/encode"
  add_method_tracer :rs256_algorithm, "Custom/#{name}/rs256_algorithm"
  add_method_tracer :sign, "Custom/#{name}/sign"
end

Encryption::Encryptors::AttributeEncryptor.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :encrypt, "Custom/#{name}/encrypt"
  add_method_tracer :decrypt, "Custom/#{name}/decrypt"
end

Encryption::Encryptors::PiiEncryptor.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :encrypt, "Custom/#{name}/encrypt"
  add_method_tracer :decrypt, "Custom/#{name}/decrypt"
end

Encryption::Encryptors::SessionEncryptor.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :encrypt, "Custom/#{name}/encrypt"
  add_method_tracer :decrypt, "Custom/#{name}/decrypt"
end

Encryption::PasswordVerifier.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :digest, "Custom/#{name}/digest"
  add_method_tracer :verify, "Custom/#{name}/verify"
end

Encryption::KmsClient.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :decrypt, "Custom/#{name}/decrypt"
  add_method_tracer :encrypt, "Custom/#{name}/encrypt"
end

Encryption::ContextlessKmsClient.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :decrypt, "Custom/#{name}/decrypt"
  add_method_tracer :encrypt, "Custom/#{name}/encrypt"
end

PwnedPasswords::BinarySearchSortedHashFile.class_eval do
  include ::NewRelic::Agent::MethodTracer
  add_method_tracer :call, "Custom/#{name}/call"
end
