require 'rails_helper'

describe PersonalKeyForNewUserPolicy do
  describe '#show_personal_key_after_initial_2fa_setup?' do
    context 'user has no personal key and made LOA1 request' do
      it 'returns true' do
        user = User.new
        session = { sp: { loa3: false } }
        policy = PersonalKeyForNewUserPolicy.new(user: user, session: session)

        expect(policy.show_personal_key_after_initial_2fa_setup?).to eq true
      end
    end

    context 'user has no personal key and visited the site directly' do
      it 'returns true' do
        user = User.new
        session = {}
        policy = PersonalKeyForNewUserPolicy.new(user: user, session: session)

        expect(policy.show_personal_key_after_initial_2fa_setup?).to eq true
      end
    end

    context 'user has a personal key' do
      it 'returns false' do
        user = User.new(personal_key: 'foo')
        session = {}
        policy = PersonalKeyForNewUserPolicy.new(user: user, session: session)

        expect(policy.show_personal_key_after_initial_2fa_setup?).to eq false
      end
    end

    context 'user does not have a personal key and made an LOA3 request' do
      it 'returns false' do
        user = User.new
        session = { sp: { loa3: true } }
        policy = PersonalKeyForNewUserPolicy.new(user: user, session: session)

        expect(policy.show_personal_key_after_initial_2fa_setup?).to eq false
      end
    end

    context 'user has a personal key and made an LOA3 request' do
      it 'returns false' do
        user = User.new(personal_key: 'foo')
        session = { sp: { loa3: true } }
        policy = PersonalKeyForNewUserPolicy.new(user: user, session: session)

        expect(policy.show_personal_key_after_initial_2fa_setup?).to eq false
      end
    end
  end
end
