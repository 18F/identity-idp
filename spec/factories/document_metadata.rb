FactoryBot.define do
  factory :document_metadata do
    document_capture_session
    document_data do
      {
        document_number: '1234567890',
        document_issued: '2020-01-01',
        document_expiration: '2030-01-01',
      }
    end
  end
end
