# frozen_string_literal: true

module UserSuppliedNameAttributes
  MAX_NAME_LENGTH = 20

  # In cases where the webauthn method is face or touch unlock, we override the name field
  # with device and browser information that may be longer than other user supplied names.
  WEBAUTN_MAX_NAME_LENGTH_EXCEPTION = 80
end
