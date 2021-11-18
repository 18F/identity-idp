module Telephony
  # @!attribute [r] carrier
  #   @return [String, nil] the carrier for the phone number
  # @!attribute [r] type
  #   @return [Symbol] returns +:mobile+, +:landline+, +:voip+ or +:unknown+ if there was an error
  # @!attribute [r] error
  #   @return [StandardError, nil] the error looking up the data if there was one
  PhoneNumberInfo = Struct.new(:carrier, :type, :error, keyword_init: true)
end
