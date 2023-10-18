require 'rails_helper'
require_relative './report_mailer_preview'

RSpec.describe ReportMailerPreview do
  subject(:mailer_preview) { ReportMailerPreview.new }

  ReportMailerPreview.instance_methods(false).each do |mailer_method|
    describe "##{mailer_method}" do
      it 'generates a preview without blowing up' do
        expect { mailer_preview.public_send(mailer_method).body }.to_not raise_error
      end
    end
  end
end
