require 'rails_helper'
require_relative './report_mailer_preview'

RSpec.describe ReportMailerPreview do
  subject(:mailer_preview) { ReportMailerPreview.new }

  describe '#warn_error' do
    it 'generates a warn_error email' do
      expect { mailer_preview.warn_error }.to_not raise_error
    end
  end
end
