require 'rails_helper'
require_relative './user_mailer_preview'

RSpec.describe UserMailerPreview do
  UserMailerPreview.instance_methods(false).each do |mailer_method|
    describe "##{mailer_method}" do
      before { create(:user) }

      it 'generates a preview without blowing up' do
        expect { UserMailerPreview.new.public_send(mailer_method) }.to_not raise_error
      end
    end
  end

  it 'has a preview method for each mailer method' do
    mailer_methods = UserMailer.instance_methods(false)
    preview_methods = UserMailerPreview.instance_methods(false)
    expect(mailer_methods - preview_methods).to be_empty
  end
end
