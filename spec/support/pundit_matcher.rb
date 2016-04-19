RSpec::Matchers.define :permit_action do |action|
  match do |policy|
    policy.public_send("#{action}?")
  end

  failure_message do |policy|
    "#{policy.class} does not permit #{action} on " \
    "#{policy.instance_values.values[1].role} for #{policy.instance_values.values[0].role}."
  end

  failure_message_when_negated do |policy|
    "#{policy.class} does not forbid #{action} on " \
    "#{policy.instance_values.values[1].role} for #{policy.instance_values.values[0].role}."
  end
end
