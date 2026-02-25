# frozen_string_literal: true

module DocAuth
  module LexisNexis
    DdpConfig = RedactedStruct.new(
      :account_id,
      :api_key,
      :base_url, # required
      :org_id,
      :request_mode,
      :trueid_account_id,
      :trueid_password,
      :trueid_username,
      :hmac_key_id,
      :hmac_secret_key,
      :warn_notifier, # optional
      :locale,
      :dpi_threshold,
      :sharpness_threshold,
      :glare_threshold, # required
      keyword_init: true,
      allowed_members: [
        :account_id,
        :base_url,
        :request_mode,
        :locale,
        :dpi_threshold,
        :sharpness_threshold,
        :glare_threshold,
      ],
    ) do
      def validate!
        raise 'config missing base_url' if !base_url
        raise 'config missing locale' if !locale
      end
    end.freeze
  end
end
