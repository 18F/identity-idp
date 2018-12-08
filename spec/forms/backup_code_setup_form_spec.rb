require 'rails_helper'

describe BackupCodeSetupForm do
  it 'returns the correct domain' do
    domain = BackupCodeSetupForm.domain_name
    expect(domain).to eq 'www.example.com'
  end
end
