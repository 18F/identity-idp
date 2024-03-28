require 'rails_helper'

RSpec.describe Idv::ProfileLogging do
  describe '#as_json' do
    context 'active profile' do
      let(:profile) { create(:profile, :active) }

      it 'returns relevant attributes with nil values omitted' do
        expect(described_class.new(profile).as_json).to eql(
          profile.slice(%i[id active activated_at created_at idv_level verified_at]),
        )
      end
    end

    context 'gpo pending profile' do
      let(:profile) { create(:profile, :verify_by_mail_pending) }
      it 'returns relevant attributes with nil values omitted' do
        expect(described_class.new(profile).as_json).to eql(
          profile.slice(
            %i[id active created_at idv_level
               gpo_verification_pending_at],
          ),
        )
      end
    end

    context 'in person pending profile' do
      let(:profile) { create(:profile, :in_person_verification_pending) }
      it 'returns relevant attributes with nil values omitted' do
        expect(described_class.new(profile).as_json).to eql(
          profile.slice(
            %i[id active created_at idv_level
               in_person_verification_pending_at],
          ),
        )
      end
    end

    context 'fraud review pending' do
      let(:profile) { create(:profile, :fraud_review_pending) }
      it 'returns relevant attributes with nil values omitted' do
        expect(described_class.new(profile).as_json).to eql(
          profile.slice(
            %i[id active created_at idv_level
               fraud_pending_reason fraud_review_pending_at],
          ),
        )
      end
    end

    context 'fraud rejection' do
      let(:profile) { create(:profile, :fraud_rejection) }
      it 'returns relevant attributes with nil values omitted' do
        expect(described_class.new(profile).as_json).to eql(
          profile.slice(
            %i[id active created_at idv_level fraud_pending_reason fraud_rejection_at],
          ),
        )
      end
    end

    context 'password reset profile' do
      let(:profile) { create(:profile, :password_reset) }
      it 'returns relevant attributes with nil values omitted' do
        expect(described_class.new(profile).as_json).to eql(
          profile.slice(
            %i[id active created_at idv_level deactivation_reason],
          ),
        )
      end
    end
  end
end
