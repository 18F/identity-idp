class MultipleMfaOptionsValidator < ActiveModel::EachValidator
  # :reek:UtilityFunction
  def validate_each(record, attribute, value)
    return if MfaPolicy.new(value).three_or_more_factors_enabled?
    record.errors.add attribute, 'must have 3 or more MFA configurations'
  end
end
