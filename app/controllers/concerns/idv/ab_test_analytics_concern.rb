# frozen_string_literal: true

module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern
    include OptInHelper

    def ab_test_analytics_buckets
      buckets = { ab_tests: {} }

      if defined?(idv_session)
        buckets[:skip_hybrid_handoff] = idv_session&.skip_hybrid_handoff
        buckets = buckets.merge(opt_in_analytics_properties)
      end

      if defined?(document_capture_session_uuid)
        lniv_args = LexisNexisInstantVerify.new(document_capture_session_uuid).
          workflow_ab_test_analytics_args
        buckets = buckets.merge(lniv_args)
      end

      if defined?(idv_session)
        phone_confirmation_session = idv_session.user_phone_confirmation_session ||
                                     PhoneConfirmationSession.new(
                                       code: nil,
                                       phone: nil,
                                       sent_at: nil,
                                       delivery_method: :sms,
                                       user: current_user,
                                     )
        buckets[:ab_tests].merge!(
          phone_confirmation_session.ab_test_analytics_args,
        )
      end

      buckets.merge!(acuant_sdk_ab_test_analytics_args)
      buckets.delete(:ab_tests) if buckets[:ab_tests].blank?
      buckets
    end
  end
end
