require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::ResultCodes do
  describe '.from_int' do
    it 'is a result code for the int' do
      result_code = DocAuth::LexisNexis::ResultCodes.from_int(1)
      expect(result_code).to be_a(DocAuth::LexisNexis::ResultCodes::ResultCode)
      expect(result_code.billed?).to eq(true)
    end

    it 'is nil when there is no matching code' do
      result_code = DocAuth::LexisNexis::ResultCodes.from_int(999)
      expect(result_code).to be_nil
    end
  end
end
