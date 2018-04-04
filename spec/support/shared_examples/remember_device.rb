shared_examples 'remember device' do
  it 'does not require 2FA on sign in'
  it 'requires 2FA on sign in after expiration'
  it 'requires 2FA on sign in for another user'
  it 'requires 2FA on sign in after phone number is changed'
end
