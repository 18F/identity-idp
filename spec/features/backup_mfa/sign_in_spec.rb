require 'rails_helper'

feature 'setting up backup MFA on sign in' do
  context 'a user only has 1 MFA method' do
    scenario 'the user is required to setup a backup MFA method'
  end

  context 'a user has 2 MFA methods' do
    scenario 'the user is not required to setup backup MFA'
  end

  context 'a user has an MFA method and a personal key' do
    scenario 'the user is not required to setup backup MFA'
  end
end
