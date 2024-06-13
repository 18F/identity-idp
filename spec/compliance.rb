require 'rails_helper'
require 'rspec_oscal_formatter'

# run `rspec spec/compliance.rb`

RSpec.configure do |config|
  config.add_formatter RSpec::RSpecOscalFormatter::Formatter
end

RSpec.describe '800-63B' do
  it 'confirms passwords are set to the appropriate minimum length',
     control_id: 'ms-01', statement_id: 'ms-01_smt',
     assessment_plan_uuid: 'da1ce957-e50e-42a0-936e-1a44f9d8a96c' do |assessment|
    expect(Devise.password_length.min).to be >= 8
  end
end
