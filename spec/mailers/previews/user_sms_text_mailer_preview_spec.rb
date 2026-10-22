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

  it 'renders the recovery notice with the configured recovery waiting period' do
    allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(3)

    message = described_class.new.account_recovery_notice

    expect(message.body.decoded.strip).to eq(
      I18n.t(
        'telephony.account_recovery_notice.sms',
        app_name: APP_NAME,
        interval: WaitPeriodFormatter.call(3.days),
      ),
    )
  end
end
