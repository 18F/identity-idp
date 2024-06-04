require 'rails_helper'

RSpec.describe Users::BackupCodeSetupController do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
        :apply_secure_headers_override,
        [:confirm_recently_authenticated_2fa, except: ['reminder', 'continue']],
        :validate_multi_mfa_selection,
      )
    end
  end

  shared_examples 'valid backup codes creation' do
    it 'creates backup codes and logs expected events' do
      stub_analytics
      allow(controller).to receive(:in_multi_mfa_selection_flow?).and_return(true)

      Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics)
      expect(PushNotification::HttpPush).to receive(:deliver).
        with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

      response

      expect(@analytics).to have_logged_event(
        'User marked authenticated',
        authentication_type: :valid_2fa_confirmation,
      )
      expect(@analytics).to have_logged_event(
        'Backup Code Setup Visited',
        success: true,
        errors: {},
        mfa_method_counts: { phone: 1 },
        error_details: nil,
        enabled_mfa_methods_count: 1,
        in_account_creation_flow: false,
      )
      expect(@analytics).to have_logged_event(
        'Backup Code Created',
        enabled_mfa_methods_count: 2,
        in_account_creation_flow: false,
      )

      expect(response).to render_template(:create)
      expect(user.backup_code_configurations.length).to eq BackupCodeGenerator::NUMBER_OF_CODES
    end
  end

  describe '#index' do
    let(:user) { create(:user, :fully_registered) }

    subject(:response) { get :index }

    before do
      stub_sign_in(user)
    end

    it 'redirects to setup confirmation screen' do
      expect(response).to redirect_to(backup_code_confirm_setup_url)
    end

    context 'in multi mfa setup flow' do
      before do
        allow(controller).to receive(:in_multi_mfa_selection_flow?).and_return(true)
      end

      it_behaves_like 'valid backup codes creation'
    end
  end

  describe '#create' do
    let(:user) { create(:user, :fully_registered) }

    subject(:response) { post :create }

    before do
      stub_sign_in(user)
    end

    it_behaves_like 'valid backup codes creation'
  end

  context 'without existing backup codes' do
    let(:user) { create(:user, :fully_registered) }

    it 'does not revoke remembered device' do
      stub_sign_in(user)
      expect(user.remember_device_revoked_at).to eq nil

      freeze_time do
        get :index
        expect(user.reload.remember_device_revoked_at).to eq nil
      end
    end
  end

  context 'with existing backup codes' do
    let(:user) { create(:user, :fully_registered, :with_backup_code) }

    it 'revokes remembered device' do
      stub_sign_in(user)
      allow(controller).to receive(:in_multi_mfa_selection_flow?).and_return(true)

      expect(user.remember_device_revoked_at).to eq nil

      freeze_time do
        get :index
        expect(user.reload.remember_device_revoked_at).to eq Time.zone.now
      end
    end
  end

  it 'deletes backup codes' do
    user = build(:user, :fully_registered, :with_authentication_app, :with_backup_code)
    stub_sign_in(user)
    expect(user.backup_code_configurations.length).to eq 10

    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 0
  end

  it 'deleting backup codes revokes remember device cookies' do
    user = build(:user, :fully_registered, :with_authentication_app, :with_backup_code)
    stub_sign_in(user)
    expect(user.remember_device_revoked_at).to eq nil

    freeze_time do
      post :delete
      expect(user.reload.remember_device_revoked_at).to eq Time.zone.now
    end
  end

  it 'does not deletes backup codes if they are the only mfa' do
    user = build(:user, :with_backup_code)
    stub_sign_in(user)

    post :delete

    expect(response).to redirect_to(account_two_factor_authentication_path)
    expect(user.backup_code_configurations.length).to eq 10
  end

  describe 'multiple MFA handling' do
    let(:mfa_selections) { ['backup_code', 'voice'] }
    before do
      @user = create(:user)
      stub_sign_in(@user)
      controller.user_session[:mfa_selections] = mfa_selections
    end

    context 'when user selects multiple mfas on account creation' do
      it 'redirects to Phone Url Page after page' do
        codes = BackupCodeGenerator.new(@user).delete_and_regenerate
        controller.user_session[:backup_codes] = codes
        post :continue

        expect(response).to redirect_to(phone_setup_url)
      end
    end

    context 'when user only selects backup code on account creation' do
      let(:mfa_selections) { ['backup_code'] }
      it 'redirects to Suggest 2nd MFA page' do
        codes = BackupCodeGenerator.new(@user).delete_and_regenerate
        controller.user_session[:backup_codes] = codes
        post :continue
        expect(response).to redirect_to(auth_method_confirmation_url)
      end
    end
  end

  context 'with multiple MFA selection turned off' do
    it 'redirects to account page' do
      user = create(:user, :fully_registered)
      stub_sign_in(user)
      codes = BackupCodeGenerator.new(user).delete_and_regenerate
      controller.user_session[:backup_codes] = codes
      post :continue
      expect(response).to redirect_to(account_url)
    end
  end

  describe '#refreshed' do
    render_views

    it 'does not 500 when codes have not been generated' do
      user = create(:user, :fully_registered)
      stub_sign_in(user)
      get :refreshed

      expect(response).to redirect_to(backup_code_setup_url)
    end
  end

  context 'user visits the Backup codes regenerate page' do
    let(:user) { create(:user) }
    before do
      stub_sign_in(user)
      stub_analytics
    end
    it 'renders the index view' do
      get :edit
      expect(@analytics).to have_logged_event(
        'Backup Code Regenerate Visited',
        hash_including(in_account_creation_flow: false),
      )
    end
  end
end
