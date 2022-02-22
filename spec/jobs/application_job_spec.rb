require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  describe '.warning_error_classes' do
    it 'is empty by default' do
      expect(described_class.warning_error_classes).to be_empty
    end
  end
end
