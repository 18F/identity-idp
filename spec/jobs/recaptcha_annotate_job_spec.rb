require 'rails_helper'

RSpec.describe RecaptchaAnnotateJob do
  subject(:instance) { described_class.new }
  let(:assessment) { create(:recaptcha_assessment) }

  describe '#perform' do
    subject(:result) { instance.perform(assessment:) }

    it 'submits annotation for assessment and destroys the record' do
      assessment
      expect(RecaptchaAnnotator).to receive(:submit_assessment).with(assessment)

      expect { result }.to change { RecaptchaAssessment.count }.by(-1)
    end
  end
end
