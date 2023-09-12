require 'rails_helper'

describe 'Idv::AllowedStep' do
  subject { Idv::AllowedStep.new(idv_session: nil)}

  context 'when condition' do
    it 'allows the welcome step' do
      expect(subject.step_allowed?(:welcome)).to be true
    end
  end
end
