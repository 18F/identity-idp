# frozen_string_literal: true

module Pii
  # Helpers for reading the "current address matches ID" PII value during the
  # rename migration from the deprecated string field `same_address_as_id`
  # (values 'true'/'false') to the boolean field `ipp_current_address_matches_id`
  # (LG-16085).
  #
  # During the 50/50 deploy window, a session may have been written by an old
  # instance (string `same_address_as_id`) or a new instance (boolean
  # `ipp_current_address_matches_id`). Read from the new field, falling back to
  # the coerced old field, per the handbook's rename-a-field guidance.
  module CurrentAddressMatchesId
    module_function

    # @param [Hash, #[]] pii keyed with symbols
    # @return [Boolean, nil]
    def read(pii)
      new_value = pii[:ipp_current_address_matches_id]
      return coerce(new_value) unless new_value.nil?

      coerce(pii[:same_address_as_id])
    end

    # Normalizes a boolean or the legacy 'true'/'false' string into a boolean.
    # @return [Boolean, nil]
    def coerce(value)
      return nil if value.nil?
      return value if value == true || value == false

      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
