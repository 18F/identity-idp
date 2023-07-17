module Idv::Engine
  Verification = Struct.new(
    :identity_verified?,
    :user_has_started_idv?,
    :user_has_consented_to_share_pii?,
    keyword_init: true,
  )
end
