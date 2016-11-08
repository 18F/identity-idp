module ControllerHelper
  VALID_PASSWORD = 'salted peanuts are best'.freeze

  def sign_in_as_admin
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in create(:user, :admin, :signed_up, password: VALID_PASSWORD)
  end

  def sign_in_as_user(user = create(:user, :signed_up, password: VALID_PASSWORD))
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user
    user
  end

  def has_before_actions(*names)
    expect(controller).to have_actions(:before, *names)
  end

  def sign_in_as_tech_user
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in create(:user, :signed_up, :tech_support, password: VALID_PASSWORD)
  end

  def sign_in_before_2fa
    sign_in_as_user
    controller.current_user.send_new_otp
    allow(controller).to receive(:user_fully_authenticated?).and_return(false)
  end

  def stub_sign_in(user = User.new(password: VALID_PASSWORD))
    allow(request.env['warden']).to receive(:authenticate!).and_return(user)
    allow(request.env['warden']).to receive(:session).and_return(user: {})
    allow(controller).to receive(:user_session).and_return(authn_at: Time.zone.now)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:confirm_two_factor_authenticated).and_return(true)
    user
  end

  def stub_sign_in_before_2fa(user = User.new(password: VALID_PASSWORD))
    allow(request.env['warden']).to receive(:authenticate!).and_return(user)
    allow(request.env['warden']).to receive(:session).and_return(user: {})
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:user_fully_authenticated?).and_return(false)
  end

  def stub_session_store
    session_store = instance_double(RedisSessionStore)
    allow(session_store).to receive(:generate_sid).and_return('random-session-id')
    allow(controller.session).to receive(:options).and_return({})
    allow(controller.session).to receive(:instance_variable_get).with('@by').
      and_return(session_store)
  end
end

RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include ControllerHelper, type: :controller

  config.before(:example, devise: true, type: :controller) do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end
end
