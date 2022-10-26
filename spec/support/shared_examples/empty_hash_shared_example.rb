RSpec.shared_examples 'the hash is blank?' do
  it 'raises an error' do
    expect { subject }.to raise_error 'payload_hash is blank?'
  end
end
