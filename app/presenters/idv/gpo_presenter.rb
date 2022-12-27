module Idv
  class GpoPresenter
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
      user_needs_address_otp_verification? ? idv_gpo_verify_path : idv_phone_path
    end

    def resend_requested?
      current_user.decorate.pending_profile_requires_verification?
    end

    private

    def user_needs_address_otp_verification?
      current_user.pending_profile?
    end
  end
end
