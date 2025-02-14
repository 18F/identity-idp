# frozen_string_literal: true

Encryption::RegionalDigestPair = RedactedStruct.new(
  :single_region_digest,
  :multi_region_digest,
  keyword_init: true,
) do
  def to_ary
    [single_region_digest, multi_region_digest]
  end

  def multi_or_single_region_digest
    multi_region_digest.presence || single_region_digest
  end
end.freeze
