module ControllerHelper
  VALID_PASSWORD = 'salted peanuts are best'.freeze

  def sign_in_as_user(user = create(:user, :signed_up, password: VALID_PASSWORD))
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user
    user
  end

  def sign_in_before_2fa(user = create(:user, :signed_up))
    sign_in_as_user(user)
    controller.current_user.create_direct_otp
    allow(controller).to receive(:user_fully_authenticated?).and_return(false)
    allow(controller).to receive(:signed_in_url).and_return(account_url)
  end

  def stub_sign_in(user = build(:user, password: VALID_PASSWORD))
    allow(request.env['warden']).to receive(:authenticate!).and_return(user)
    allow(request.env['warden']).to receive(:session).and_return(user: {})
    allow(controller).to receive(:user_session).and_return(authn_at: Time.zone.now)
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
  end

  def stub_verify_steps_one_and_two(user)
    user_session = {}
    stub_sign_in(user)
    idv_session = Idv::Session.new(
      user_session: user_session, current_user: user,
      service_provider: nil
    )
    idv_session.applicant = {
      first_name: 'Some',
      last_name: 'One',
      uuid: SecureRandom.uuid,
      dob: 50.years.ago.to_date.to_s,
      ssn: '666-12-1234',
    }.with_indifferent_access
    idv_session.profile_confirmation = true
    allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(user_session)
  end

  def stub_user_with_applicant_data(user, applicant)
    user_session = {}
    stub_sign_in(user)
    idv_session = Idv::Session.new(
      user_session: user_session, current_user: user,
      service_provider: nil
    )
    idv_session.applicant = applicant.with_indifferent_access
    idv_session.profile_confirmation = true
    allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(user_session)
  end

  def stub_decorated_user_with_pending_profile(user)
    decorated_user = instance_double(UserDecorator)
    allow(user).to receive(:decorate).and_return(decorated_user)
    allow(user).to receive(:pending_profile).and_return(pending_profile)
    allow(decorated_user).to receive(:pending_profile_requires_verification?).
      and_return(has_pending_profile)
    allow(decorated_user).to receive(:threatmetrix_review_pending?).and_return(false)
    decorated_user
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
