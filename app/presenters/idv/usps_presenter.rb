module Idv
  class UspsPresenter
    include Rails.application.routes.url_helpers

    attr_reader :current_user

    def initialize(current_user, url_options)
      @current_user = current_user
      @url_options = url_options
    end

    def title
      letter_already_sent? ? I18n.t('idv.titles.mail.resend') : I18n.t('idv.titles.mail.verify')
    end

    def byline
      if usps_mail_bounced?
        I18n.t('idv.messages.usps.new_address')
      else
        I18n.t('idv.messages.usps.address_on_file')
      end
    end

    def button
      letter_already_sent? ? I18n.t('idv.buttons.mail.resend') : I18n.t('idv.buttons.mail.send')
    end

    def back_path
      user_needs_address_otp_verification? ? verify_account_path : idv_phone_path
    end

    def usps_mail_bounced?
      current_user.decorate.usps_mail_bounced?
    end

    def url_options
      @url_options
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
