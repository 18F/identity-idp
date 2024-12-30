require 'rails_helper'
require_relative './user_mailer_preview'

RSpec.describe UserMailerPreview do
  it_behaves_like 'a mailer preview', preview_methods_that_can_be_missing: [:in_person_please_call]

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
