require 'rails_helper'

RSpec.describe Idv::InPerson::ChooseIdTypePresenter do
  describe '#choose_id_type_info_text' do
    it 'returns the "in_person_proofing.info.choose_id_type" translation' do
      expect(subject.choose_id_type_info_text).to eq(t('in_person_proofing.info.choose_id_type'))
    end
  end

  describe '#current_step' do
    it 'returns verify info' do
      expect(subject.current_step).to eq(:verify_info)
    end
  end

  describe '#hybrid_flow?' do
    it 'returns false' do
      expect(subject.hybrid_flow?).to be(false)
    end
  end

  describe '#step_indicator_steps' do
    it 'returns the IPP step indicator steps' do
      expect(subject.step_indicator_steps).to eq(
        Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP,
      )
    end
  end
end
