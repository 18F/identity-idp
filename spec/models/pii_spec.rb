require 'rails_helper'

describe PII do
  let(:user) { create(:user, :signed_up) }
  let(:pii) do
    PII.create(
      user_id: user.id
    )
  end

  subject { pii }

  it { is_expected.to belong_to(:user) }

  describe 'allows only one active PII per user' do
    it 'prevents create! via ActiveRecord uniqueness validation' do
      pii.active = true
      pii.save!
      expect do
        PII.create!(user_id: user.id, active: true)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents save! via psql unique partial index' do
      pii.active = true
      pii.save!
      expect do
        another_pii = PII.new(user_id: user.id, active: true)
        another_pii.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '#activate!' do
    it 'activates current PII, de-activates all other PII for the user' do
      active_pii = PII.create(user: user, active: true)
      pii.activate!
      active_pii.reload
      expect(active_pii).to_not be_active
      expect(pii).to be_active
    end
  end
end
