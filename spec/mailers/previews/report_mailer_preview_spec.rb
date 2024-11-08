require 'rails_helper'
require_relative './report_mailer_preview'

RSpec.describe ReportMailerPreview do
  it_behaves_like 'a mailer preview'
end
