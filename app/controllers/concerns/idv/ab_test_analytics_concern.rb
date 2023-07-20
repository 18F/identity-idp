module Idv
  module AbTestAnalyticsConcern
    def ab_test_analytics_args
      acuant_sdk_ab_test_analytics_args.
        merge(getting_started_ab_test_analytics_args)
    end

    def acuant_sdk_ab_test_analytics_args
      return {} if document_capture_session_uuid.blank?

      {
        acuant_sdk_upgrade_ab_test_bucket:
          AbTests::ACUANT_SDK.bucket(document_capture_session_uuid),
      }
    end

    def getting_started_ab_test_analytics_args
      return {} if current_user.blank?

      {
        getting_started_ab_test_bucket:
          getting_started_ab_test_bucket,
      }
    end
  end
end
