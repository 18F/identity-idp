require 'rails_helper'
require_relative './user_sms_text_mailer_preview'

RSpec.describe UserSmsTextMailerPreview do
  let(:mailer_class) { described_class.class_name.gsub(/Preview$/, '').constantize }

  it 'has a mailer method for each preview' do
    mailer_methods = mailer_class.instance_methods(false)
    preview_methods = described_class.instance_methods(false)
    expect(preview_methods - mailer_methods).to be_empty
  end

  it 'has a preview method for every SMS message' do
    i18n_key_values = I18n::Tasks::BaseTask.new.data[:en].key_values
    sms_messages = i18n_key_values.select do |msg|
      /^telephony.*\.sms$/.match(msg[0])
    end
    preview_methods = described_class.instance_methods(false)
    expect(sms_messages.count).to eq(preview_methods.count)
  end
end
