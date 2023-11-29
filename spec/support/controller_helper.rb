module ControllerHelper
  VALID_PASSWORD = 'salted peanuts are best'.freeze

  def sign_in_as_user(user = create(:user, :fully_registered, password: VALID_PASSWORD))
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user
    controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = true
    user
  end

  def sign_in_before_2fa(user = create(:user, :fully_registered))
    sign_in_as_user(user)
    controller.current_user.create_direct_otp
  end

  def stub_sign_in(user = build(:user, password: VALID_PASSWORD))
    allow(request.env['warden']).to receive(:authenticate!).and_return(user)
    allow(request.env['warden']).to receive(:session).and_return(user: {})
    allow(controller).to receive(:user_session).and_return({}.with_indifferent_access)
    controller.auth_methods_session.authenticate!(TwoFactorAuthenticatable::AuthMethod::SMS)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:confirm_two_factor_authenticated).and_return(true)
    allow(controller).to receive(:user_fully_authenticated?).and_return(true)
    allow(controller).to receive(:remember_device_expired_for_sp?).and_return(false)
    user
  end

  def stub_sign_in_before_2fa(user = build(:user, password: VALID_PASSWORD))
    allow(request.env['warden']).to receive(:authenticate!).and_return(user)
    allow(request.env['warden']).to receive(:session).and_return(user: {})
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:user_fully_authenticated?).and_return(false)
    allow(controller).to receive(:signed_in_url).and_return(account_url)
    controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = true
  end

  def stub_idv_steps_before_verify_step(
    user,
    applicant: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
  )
    user_session = {}
    stub_sign_in(user)
    idv_session = Idv::Session.new(
      user_session: user_session, current_user: user,
      service_provider: nil
    )
    idv_session.applicant = applicant
    allow(subject).to receive(:confirm_idv_applicant_created).and_return(true)
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(user_session)
  end

  def stub_verify_steps_one_and_two(
    user,
    applicant: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
  )
    user_session = ActiveSupport::HashWithIndifferentAccess.new
    stub_sign_in(user)
    idv_session = Idv::Session.new(
      user_session: user_session, current_user: user,
      service_provider: nil
    )
    idv_session.applicant = applicant
    idv_session.resolution_successful = true
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(user_session)
  end

  def stub_user_with_pending_profile(user)
    allow(user).to receive(:pending_profile).and_return(pending_profile)
    allow(user).to receive(:gpo_verification_pending_profile?).
      and_return(has_pending_profile)
    user
  end

  def stub_identity(user, params)
    ServiceProviderIdentity.new(params.merge(user: user)).save
  end
end

RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include ControllerHelper, type: :controller

  config.before(:example, devise: true, type: :controller) do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end
end
