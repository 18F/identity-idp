# frozen_string_literal: true

# rubocop:disable Style/MutableConstant
module Pii
  Address = RedactedData.define(:state, :zipcode, :city, :address1, :address2)
end
# rubocop:enable Style/MutableConstant
