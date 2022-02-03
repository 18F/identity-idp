require 'rails_helper'

RSpec.describe 'two_factor_authentication/sms_opt_in/new.html.erb' do
  let(:phone_configuration) { build(:phone_configuration) }
  let(:has_other_auth_methods) { true }

  before do
    assign(:phone_configuration, phone_configuration)
    assign(:has_other_auth_methods, has_other_auth_methods)
  end
end
