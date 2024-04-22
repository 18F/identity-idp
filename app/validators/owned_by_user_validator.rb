# frozen_string_literal: true

class OwnedByUserValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.user&.id == record.user&.id
    record.errors.add attribute, 'must be owned by the user'
  end
end
