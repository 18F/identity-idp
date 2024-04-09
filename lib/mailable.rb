# frozen_string_literal: true

module Mailable
  extend ActiveSupport::Concern

  private

  def email_with_name(email, name)
    # http://stackoverflow.com/a/8106387/358804
    address = Mail::Address.new(email)
    address.display_name = name
    address.format
  end

  def attach_images
    attachments.inline['logo.png'] = File.read('app/assets/images/email/logo.png')
  end
end
