module Idv
  class GpoPresenter
    include Rails.application.routes.url_helpers

    attr_reader :current_user, :url_options

    def initialize(current_user, url_options)
      @current_user = current_user
      @url_options = url_options
    end

    def title
      letter_already_sent? ? I18n.t('idv.titles.mail.resend') : I18n.t('idv.titles.mail.verify')
    end

    def byline
      if gpo_mail_bounced?
        I18n.t('idv.messages.gpo.new_address')
      else
        I18n.t('idv.messages.gpo.address_on_file')
      end
    end

    def button
      letter_already_sent? ? I18n.t('idv.buttons.mail.resend') : I18n.t('idv.buttons.mail.send')
    end

    def fallback_back_path
      user_needs_address_otp_verification? ? idv_gpo_verify_path : idv_phone_path
    end

    def gpo_mail_bounced?
      current_user.decorate.gpo_mail_bounced?
    end

    def letter_already_sent?
      gpo_mail_service.any_mail_sent?
    end

    private

    def gpo_mail_service
      @gpo_mail_service ||= Idv::GpoMail.new(current_user)
    end

    def user_needs_address_otp_verification?
      current_user.pending_profile?
    end
  end
end
