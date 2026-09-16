require 'rails_helper'
require_relative './sms_text_mailer_preview'

RSpec.describe SmsTextMailerPreview do
  let(:mailer_class) { described_class.class_name.gsub(/Preview$/, '').constantize }

  it 'has a preview method for each text' do
    mailer_methods = mailer_class.instance_methods(false)
    preview_methods = described_class.instance_methods(false)
    expect(mailer_methods - preview_methods).to eql([])
  end
end
