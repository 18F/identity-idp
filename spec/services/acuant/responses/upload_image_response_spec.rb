describe Acuant::Responses::UploadImageResponse do
  it 'is a successful response' do
    response = described_class.new

    expect(response.success?).to eq(true)
    expect(response.errors).to eq([])
    expect(response.exception).to be_nil
  end
end
