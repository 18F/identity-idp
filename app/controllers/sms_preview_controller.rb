# frozen_string_literal: true

class SmsPreviewController < ApplicationController
  def show
    show_sms_preview
  end

  private

  def show_sms_preview
    redirect_to '/rails/mailers/sms_text_mailer'
  end
end
