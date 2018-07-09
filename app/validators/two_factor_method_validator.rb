class TwoFactorMethodValidator < ActiveModel::EachValidator
  # Options:
  #   +:state+ - 'configurable', 'enabled', 'available', etc.
  #   +:user+ - the attribute holding the user
  #   +:or_in+ - additional values assumed to be valid
  #   +:message+ - error message to use
  #
  # Default 'state' is 'configurable'. Default 'user' attribute is 'user'.
  #
  def validate_each(form, attribute, value)
    if value.match?(/[a-z][_a-z]+[a-z]/)
      return true if assumed_valid(value)
      state = (options[:state] || 'configurable')
      return true if manager_for_method(form, value)&.send(:"#{state}?")
    end
    form.errors[attribute] << (options[:message] || 'is not an available second factor')
  end

  private

  def assumed_valid(value)
    (options[:or_in] || []).include?(value)
  end

  def manager_for_method(form, value)
    user_attribute = (options[:user] || 'user')
    user = form.send(user_attribute)
    user&.two_factor_method_manager&.configuration_manager(value)
  end
end
