require 'rails_helper'

require 'user_updater'

describe UserUpdater do
  let(:user) { create(:user) }

  describe '.confirm_2fa_for' do
    before { UserUpdater.confirm_2fa_for(user) }

    it 'sets second factor to email' do
      expect(user.second_factors.pluck(:name)).to eq %w(Email)
    end

    it 'sets second_factor_confirmed_at to now' do
      expect(user.second_factor_confirmed_at).to be_present
    end
  end

  describe '.create_security_answers_for' do
    before { UserUpdater.create_security_answers_for(user) }

    it 'creates security_answers' do
      expect(user.security_answers.size).to eq 5
    end

    it 'creates security_answers for active questions only' do
      active_ids = SecurityQuestion.where(active: true).pluck(:id)
      user_question_ids = user.security_answers.pluck(:security_question_id)

      expect((active_ids & user_question_ids).size).to eq 5
    end
  end
end
