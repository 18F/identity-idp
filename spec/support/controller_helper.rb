module ControllerHelper
  def sign_in_as_admin
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in FactoryGirl.create(:user, :admin, :signed_up)
  end

  def sign_in_as_user
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in FactoryGirl.create(:user, :signed_up)
  end

  def has_before_actions(*names)
    expect(controller).to have_actions(:before, *names)
  end

  def sign_in_as_tech_user
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in create(:user, :signed_up, :tech_support)
  end

  def sign_in_before_2fa
    sign_in_as_user
    allow(controller).to receive(:user_fully_authenticated?).and_return(false)
  end
end

RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include ControllerHelper, type: :controller

  config.before(:example, devise: true, type: :controller) do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end
end
