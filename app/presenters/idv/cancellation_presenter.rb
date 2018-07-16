module Idv
  class CancellationPresenter < FailurePresenter
    delegate :idv_jurisdiction_path,
             :idv_otp_delivery_method_path,
             :idv_phone_path,
             :idv_session_path,
             :idv_session_success_path,
             :idv_review_path,
             :idv_usps_path,
             :login_two_factor_path,
             :t,
             to: :view_context

    attr_reader :step, :view_context

    def initialize(step:, view_context:)
      super(:warning)
      @step = step
      @view_context = view_context
    end

    def title
      t('headings.cancellations.prompt')
    end

    def header
      t('headings.cancellations.prompt')
    end

    def cancellation_warnings
      [
        t('idv.cancel.warnings.warning_1'),
        t('idv.cancel.warnings.warning_2'),
        t('idv.cancel.warnings.warning_3', app: APP_NAME),
        t('idv.cancel.warnings.warning_4'),
        t('idv.cancel.warnings.warning_5'),
      ]
    end

    def go_back_path
      {
        jurisdiction: idv_jurisdiction_path,
        phone_otp_delivery_selection: idv_otp_delivery_method_path,
        phone_otp_verification: login_two_factor_path(otp_delivery_preference: :sms),
        phone: idv_phone_path,
        profile: idv_session_path,
        profile_success: idv_session_success_path,
        review: idv_review_path,
        usps: idv_usps_path,
      }[step] || idv_path
    end
  end
end
