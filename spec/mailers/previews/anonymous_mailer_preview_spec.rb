require 'rails_helper'
require_relative './anonymous_mailer_preview'

RSpec.describe AnonymousMailerPreview do
  AnonymousMailerPreview.instance_methods(false).each do |mailer_method|
    describe "##{mailer_method}" do
      it 'generates a preview without raising an error' do
        expect { AnonymousMailerPreview.new.public_send(mailer_method).body }.to_not raise_error
      end
    end
  end

  it 'has a preview method for each mailer method' do
    mailer_methods = AnonymousMailer.instance_methods(false)
    preview_methods = AnonymousMailerPreview.instance_methods(false)
    expect(mailer_methods - preview_methods).to be_empty
  end
end
