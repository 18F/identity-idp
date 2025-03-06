# frozen_string_literal: true

Encryption::RegionalEncryptedValuePair = RedactedStruct.new(
  :single_region_encrypted_value,
  :multi_region_encrypted_value,
  keyword_init: true,
) do
  def to_ary
    [single_region_encrypted_value, multi_region_encrypted_value]
  end

  def multi_or_single_region_encrypted_value
    multi_region_encrypted_value.presence || single_region_encrypted_value
  end
end.freeze
