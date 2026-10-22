require 'rails_helper'

RSpec.describe MfaSetupSession do
  let(:user_session) { {} }
  subject(:mfa_setup_session) { described_class.new(user_session:) }

  describe '#selections' do
    it 'returns nil when unset' do
      expect(mfa_setup_session.selections).to be_nil
    end

    it 'reads the stored selections' do
      user_session[:mfa_selections] = ['phone', 'backup_code']
      expect(mfa_setup_session.selections).to eq(['phone', 'backup_code'])
    end
  end

  describe '#selections=' do
    it 'writes selections into the session' do
      mfa_setup_session.selections = ['phone']
      expect(user_session[:mfa_selections]).to eq(['phone'])
    end
  end

  describe '#selections?' do
    it 'is false when blank' do
      expect(mfa_setup_session.selections?).to eq(false)
      user_session[:mfa_selections] = []
      expect(mfa_setup_session.selections?).to eq(false)
    end

    it 'is true when present' do
      user_session[:mfa_selections] = ['phone']
      expect(mfa_setup_session.selections?).to eq(true)
    end
  end

  describe '#selection_count' do
    it 'returns 0 when unset' do
      expect(mfa_setup_session.selection_count).to eq(0)
    end

    it 'returns the number of selections' do
      user_session[:mfa_selections] = ['phone', 'backup_code']
      expect(mfa_setup_session.selection_count).to eq(2)
    end
  end

  describe '#selection_index' do
    it 'defaults to 0' do
      expect(mfa_setup_session.selection_index).to eq(0)
    end

    it 'returns the stored index' do
      user_session[:mfa_selection_index] = 3
      expect(mfa_setup_session.selection_index).to eq(3)
    end
  end

  describe '#next_selection_choice' do
    it 'reads and writes the stored choice' do
      expect(mfa_setup_session.next_selection_choice).to be_nil
      mfa_setup_session.next_selection_choice = 'phone'
      expect(user_session[:next_mfa_selection_choice]).to eq('phone')
      expect(mfa_setup_session.next_selection_choice).to eq('phone')
    end
  end

  describe '#next_setup_choice' do
    context 'without selections' do
      it 'returns nil and does not set an index' do
        expect(mfa_setup_session.next_setup_choice).to be_nil
        expect(user_session).not_to have_key(:mfa_selection_index)
      end
    end

    context 'with selections' do
      before { user_session[:mfa_selections] = ['phone', 'auth_app', 'backup_code'] }

      it 'returns the first choice and records index 0 when nothing set up yet' do
        expect(mfa_setup_session.next_setup_choice).to eq('auth_app')
        expect(user_session[:mfa_selection_index]).to eq(0)
      end

      it 'advances relative to the current selection choice' do
        user_session[:next_mfa_selection_choice] = 'auth_app'
        expect(mfa_setup_session.next_setup_choice).to eq('backup_code')
        expect(user_session[:mfa_selection_index]).to eq(1)
      end

      it 'returns nil past the last selection' do
        user_session[:next_mfa_selection_choice] = 'backup_code'
        expect(mfa_setup_session.next_setup_choice).to be_nil
        expect(user_session[:mfa_selection_index]).to eq(2)
      end
    end
  end

  describe '#in_account_creation_flow?' do
    it 'defaults to false' do
      expect(mfa_setup_session.in_account_creation_flow?).to eq(false)
    end

    it 'reflects the stored value' do
      user_session[:in_account_creation_flow] = true
      expect(mfa_setup_session.in_account_creation_flow?).to eq(true)
    end
  end

  describe '#platform_authenticator_available?' do
    it 'defaults to false' do
      expect(mfa_setup_session.platform_authenticator_available?).to eq(false)
    end

    it 'is true only when explicitly true' do
      user_session[:platform_authenticator_available] = true
      expect(mfa_setup_session.platform_authenticator_available?).to eq(true)
    end

    it 'is false for truthy-but-not-true values' do
      user_session[:platform_authenticator_available] = 'true'
      expect(mfa_setup_session.platform_authenticator_available?).to eq(false)
    end
  end

  describe '#threatmetrix_session_id' do
    it 'reads the stored session id' do
      user_session[:sign_up_threatmetrix_session_id] = 'abc-123'
      expect(mfa_setup_session.threatmetrix_session_id).to eq('abc-123')
    end
  end

  describe '#take_second_mfa_reminder_conversion!' do
    it 'returns and removes the flag' do
      user_session[:second_mfa_reminder_conversion] = true
      expect(mfa_setup_session.take_second_mfa_reminder_conversion!).to eq(true)
      expect(user_session).not_to have_key(:second_mfa_reminder_conversion)
    end

    it 'returns nil when unset' do
      expect(mfa_setup_session.take_second_mfa_reminder_conversion!).to be_nil
    end
  end

  describe '#clear_selections!' do
    it 'removes the stored selections' do
      user_session[:mfa_selections] = ['phone']
      mfa_setup_session.clear_selections!
      expect(user_session).not_to have_key(:mfa_selections)
    end
  end
end
