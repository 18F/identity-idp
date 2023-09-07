module Idv::ByMail
  class RequestLetterPresenter
    include Rails.application.routes.url_helpers

    attr_reader :current_user, :url_options

    def initialize(current_user, url_options)
      @current_user = current_user
      @url_options = url_options
    end

    def title
      resend_requested? ? I18n.t('idv.titles.mail.resend') : I18n.t('idv.titles.mail.verify')
    end

    def button
      resend_requested? ? I18n.t('idv.buttons.mail.resend') : I18n.t('idv.buttons.mail.send')
    end

    def fallback_back_path
      return idv_verify_info_path if OutageStatus.new.any_phone_vendor_outage?
      user_needs_address_otp_verification? ? idv_enter_verify_by_mail_code_path : idv_phone_path
    end

    def resend_requested?
      current_user.gpo_verification_pending_profile?
    end

    def back_or_cancel_partial
      if FeatureManagement.idv_by_mail_only?
        'idv/doc_auth/cancel'
      else
        'idv/shared/back'
      end
    end

    def back_or_cancel_parameters
      if FeatureManagement.idv_by_mail_only?
        { step: 'gpo' }
      else
        { fallback_path: fallback_back_path }
      end
    end

    private

    def user_needs_address_otp_verification?
      current_user.pending_profile?
    end
  end
end
