Encryption::RegionalCiphertextPair = RedactedStruct.new(
  :single_region_ciphertext, :multi_region_ciphertext, keyword_init: true
) do
  def to_ary
    [single_region_ciphertext, multi_region_ciphertext]
  end
end
