require 'rails_helper'

describe Funnel::DocAuth::LogDocumentError do
  describe '::call' do
    it 'sets last error when doc auth log exists' do
      doc_auth_log = create(:doc_auth_log, user_id: 1)
      puts Funnel::DocAuth::LogDocumentError.call(1, 'test')
      expect(doc_auth_log.reload.last_document_error).to eq 'test'
    end

    it 'returns nil if doc auth log does not exist' do
      result = Funnel::DocAuth::LogDocumentError.call(1, 'test')
      expect(result).to eq nil
    end
  end
end
