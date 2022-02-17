require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  context 'warning error classes' do
    it 'returns empty class' do
      expect(described_class.warning_error_classes.empty?).to be true
    end
  end
end
