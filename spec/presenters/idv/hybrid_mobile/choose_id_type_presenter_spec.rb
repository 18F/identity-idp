require 'rails_helper'

RSpec.describe Idv::HybridMobile::ChooseIdTypePresenter do
  describe '#choose_id_type_info_text' do
    it 'returns the "doc_auth.info.choose_id_type" translation' do
      expect(subject.choose_id_type_info_text).to eq(t('doc_auth.info.choose_id_type'))
    end
  end

  describe '#current_step' do
    it 'returns verify id' do
      expect(subject.current_step).to eq(:verify_id)
    end
  end

  describe '#hybrid_flow?' do
    it 'returns true' do
      expect(subject.hybrid_flow?).to be(true)
    end
  end

  describe '#step_indicator_steps' do
    it 'returns the step indicator steps' do
      expect(subject.step_indicator_steps).to eq(
        Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS,
      )
    end
  end
end
