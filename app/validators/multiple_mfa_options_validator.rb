class MultipleMfaOptionsValidator < ActiveModel::EachValidator
  # :reek:UtilityFunction
  def validate_each(record, attribute, value)
    return if MfaPolicy.new(value).multiple_factors_enabled?
    record.errors.add attribute, 'must have multiple MFA configurations'
  end
end
