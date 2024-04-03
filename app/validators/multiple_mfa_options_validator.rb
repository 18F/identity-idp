# frozen_string_literal: true

class MultipleMfaOptionsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if MfaPolicy.new(value).multiple_factors_enabled?
    record.errors.add attribute, 'must have 2 or more MFA configurations'
  end
end
