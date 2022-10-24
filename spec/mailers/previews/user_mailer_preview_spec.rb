require 'rails_helper'
require_relative './user_mailer_preview'

RSpec.describe UserMailerPreview do
  UserMailerPreview.instance_methods(false).each do |mailer_method|
    describe "##{mailer_method}" do
      it 'generates a preview without blowing up' do
        expect { UserMailerPreview.new.public_send(mailer_method) }.to_not raise_error
      end
    end
  end

  it 'has a preview method for each mailer method' do
    mailer_methods = UserMailer.instance_methods(false)
    preview_methods = UserMailerPreview.instance_methods(false)
    mailer_helper_methods = [:email_address, :user, :validate_user_and_email_address, :add_metadata]
    expect(mailer_methods - mailer_helper_methods - preview_methods).to be_empty
  end

  it 'uses user and email records that cannot be saved' do
    expect(User.count).to eq(0)
    user = UserMailerPreview.new.send(:user)
    expect { user.save }.to raise_error
    expect { user.save! }.to raise_error
    expect(User.count).to eq(0)

    expect(EmailAddress.count).to eq(0)
    email_address_record = UserMailerPreview.new.send(:email_address_record)
    expect { email_address_record.save }.to raise_error
    expect { email_address_record.save! }.to raise_error
    expect(EmailAddress.count).to eq(0)
  end
end
