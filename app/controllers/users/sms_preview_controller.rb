# frozen_string_literal: true

module Users
  class SmsPreviewController < ApplicationController
    def show
      redirect_to '/rails/mailers/sms_text_mailer'
    end
  end
end
