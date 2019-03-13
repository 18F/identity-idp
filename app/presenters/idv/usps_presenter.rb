module Idv
  class UspsPresenter
    include Rails.application.routes.url_helpers

    attr_reader :current_user

    def initialize(current_user)
      @current_user = current_user
    end

    def title
      letter_already_sent? ? I18n.t('idv.titles.mail.resend') : I18n.t('idv.titles.mail.verify')
    end

    def byline
      if current_user.decorate.usps_mail_bounced?
        I18n.t('idv.messages.usps.new_address')
      else
        I18n.t('idv.messages.usps.address_on_file')
      end
    end

    def button
      letter_already_sent? ? I18n.t('idv.buttons.mail.resend') : I18n.t('idv.buttons.mail.send')
    end

    def cancel_path
      return verify_account_path if user_needs_address_otp_verification?

      idv_cancel_path
    end

    def usps_mail_bounced?
      current_user.decorate.usps_mail_bounced?
    end

    private

    def usps_mail_service
      @usps_mail_service ||= Idv::UspsMail.new(current_user)
    end

    def letter_already_sent?
      usps_mail_service.any_mail_sent?
    end

    def user_needs_address_otp_verification?
      current_user.decorate.pending_profile?
    end
  end
end
