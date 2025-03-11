require 'rails_helper'

RSpec.describe RecaptchaAnnotateJob do
  subject(:instance) { described_class.new }
  let(:assessment) { create(:recaptcha_assessment) }

  describe '#perform' do
    subject(:result) { instance.perform(assessment_id: recaptcha_assessment.id) }

    it 'submits annotation for assessment' do
      expect(RecaptchaAnnotator).to receive(:submit_assessment).with(assessment)

      result
    end
  end
end
