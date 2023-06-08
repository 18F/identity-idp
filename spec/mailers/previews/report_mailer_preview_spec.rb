require 'rails_helper'
require_relative './report_mailer_preview'

RSpec.describe ReportMailerPreview do
  describe '#warn_error' do
    it 'generates a warn_error email' do
      expect { ReportMailerPreview.warn_error }.to_not raise_error
    end
  end
end
