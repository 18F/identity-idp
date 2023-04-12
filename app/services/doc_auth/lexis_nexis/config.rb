module DocAuth
  module LexisNexis
    Config = RedactedStruct.new(
      :account_id,
      :base_url, # required
      :request_mode,
      :trueid_account_id,
      :trueid_noliveness_cropping_workflow,
      :trueid_noliveness_nocropping_workflow,
      :trueid_password,
      :trueid_username,
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
        :trueid_noliveness_cropping_workflow,
        :trueid_noliveness_nocropping_workflow,
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
