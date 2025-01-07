require 'rails_helper'
require_relative './anonymous_mailer_preview'

RSpec.describe AnonymousMailerPreview do
  it_behaves_like 'a mailer preview'
end
