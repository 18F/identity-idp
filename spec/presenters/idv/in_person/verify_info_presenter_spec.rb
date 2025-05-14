require 'rails_helper'

RSpec.describe Idv::InPerson::VerifyInfoPresenter do
  let(:enrollment) { create(:in_person_enrollment, :establishing) }

  subject { described_class.new(enrollment: enrollment) }

  describe '#step_indicator_steps' do
    it 'returns the IPP step indicator steps' do
      expect(subject.step_indicator_steps).to eq(
        Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP,
      )
    end
  end

  describe '#identity_info_partial' do
    context 'when enrollment is a passport enrollment' do
      let(:enrollment) { create(:in_person_enrollment, :establishing, :passport_book) }

      subject { described_class.new(enrollment: enrollment) }

      it 'returns "passport_section"' do
        expect(subject.identity_info_partial).to eq('passport_section')
      end
    end

    context 'when enrollment is not passport enrollment' do
      let(:enrollment) { create(:in_person_enrollment, :establishing, :state_id) }

      subject { described_class.new(enrollment: enrollment) }

      it 'returns "state_id_section"' do
        expect(subject.identity_info_partial).to eq('state_id_section')
      end
    end
  end
end
