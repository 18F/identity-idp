module DocAuth
  module LexisNexis
    Config = RedactedStruct.new(
      :account_id,
      :base_url, # required
      :request_mode,
      :trueid_account_id,
      :trueid_liveness_workflow,
      :trueid_noliveness_workflow,
      :trueid_password,
      :trueid_username,
      :trueid_timeout, # optional
      :timeout, # optional
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
        :timeout,
        :trueid_liveness_workflow,
        :trueid_noliveness_workflow,
        :trueid_timeout,
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
    end
  end
end
