Encryption::RegionalCiphertextPair = RedactedStruct.new(
  :single_region_ciphertext, :multi_region_ciphertext, keyword_init: true
) do
  def to_ary
    [single_region_ciphertext, multi_region_ciphertext]
  end

  def multi_or_single_region_ciphertext
    if IdentityConfig.store.aws_kms_multi_region_read_enabled
      multi_region_ciphertext.presence || single_region_ciphertext
    else
      single_region_ciphertext
    end
  end
end
