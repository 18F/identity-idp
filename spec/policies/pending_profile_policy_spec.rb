require 'rails_helper'

RSpec.describe PendingProfilePolicy do
  let(:user) { create(:user) }
  let(:resolved_authn_context_result) { double(AuthnContextResolver) }
  subject(:policy) do
    described_class.new(
      user: user,
      resolved_authn_context_result: resolved_authn_context_result,
    )
  end

  describe '#user_has_pending_profile?' do
    context 'when user is nil' do
      subject(:policy) do
        described_class.new(
          user: nil,
          resolved_authn_context_result: resolved_authn_context_result,
        )
      end

      it 'returns false' do
        expect(subject.user_has_pending_profile?).to be(false)
      end
    end

    context 'when facial match is requested' do
      context 'when resolved authn context result requires facial match' do
        before do
          allow(resolved_authn_context_result).to receive(:facial_match?).and_return(true)
        end

        [:unsupervised_with_selfie, :in_person].each do |idv_level|
          context "when the user has a pending facial match profile with #{idv_level} idv level" do
            before do
              create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
            end

            it 'returns true' do
              expect(subject.user_has_pending_profile?).to be(true)
            end
          end
        end

        [:legacy_in_person, :legacy_unsupervised].each do |idv_level|
          context "when the user has a pending legacy match profile with #{idv_level} idv level" do
            before do
              create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
            end

            it 'returns false' do
              expect(subject.user_has_pending_profile?).to be(false)
            end
          end
        end

        [:in_person,
         :unsupervised_with_selfie,
         :legacy_in_person,
         :legacy_unsupervised].each do |idv_level|
          context "user has an active profile with #{idv_level} idv level" do
            before do
              create(:profile, :active, :verified, idv_level: idv_level, user: user)
            end

            it 'returns false' do
              expect(subject.user_has_pending_profile?).to eq(false)
            end
          end
        end
      end
    end

    context 'when facial match is not requested' do
      before do
        allow(resolved_authn_context_result).to receive(:facial_match?).and_return(false)
      end

      [:unsupervised_with_selfie].each do |idv_level|
        context "when the user has a pending #{idv_level} profile" do
          before do
            create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
          end

          it 'returns false' do
            expect(subject.user_has_pending_profile?).to eq(false)
          end
        end
      end

      [:in_person, :legacy_in_person, :legacy_unsupervised].each do |idv_level|
        context "when the user has a pending #{idv_level} profile" do
          before do
            create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
          end

          it 'returns true' do
            expect(subject.user_has_pending_profile?).to eq(true)
          end
        end
      end

      [:unsupervised_with_selfie].each do |idv_level|
        context 'when the user has a pending fraud review profile' do
          before do
            create(:profile, :fraud_review_pending, idv_level: idv_level, user: user)
          end

          it 'returns true' do
            expect(subject.user_has_pending_profile?).to eq(true)
          end
        end
      end

      [:in_person,
       :unsupervised_with_selfie,
       :legacy_in_person,
       :legacy_unsupervised].each do |idv_level|
        context "user has an active profile with #{idv_level} idv level" do
          before do
            create(:profile, :active, :verified, idv_level: idv_level, user: user)
          end

          it 'returns false' do
            expect(subject.user_has_pending_profile?).to eq(false)
          end
        end
      end
    end
  end
end
