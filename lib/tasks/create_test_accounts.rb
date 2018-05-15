#!/usr/bin/env ruby

# Create test user accounts
#
# This script includes functions that can be used to create test accounts
# locally and in our integration environments.


# Creates a user account with given attributes
def create_account(email: 'joe.smith@email.com', password: 'salty pickles', mfa_phone: '1234567890', verified: true,
                   first_name: 'joe', middle_name: 'jingles', last_name: 'smith', dob: '1/1/1970', ssn: '123456789',
                   address1: '123 America St', address2: 'Apt 1776', city: 'Washington', state: 'DC', zipcode: '20001', phone: '9876543210')

  email.downcase!
  user = User.create!(email: email)
  user.skip_confirmation!
  user.reset_password(password, password)
  user.phone = mfa_phone || phone
  user.phone_confirmed_at = Time.zone.now
  user.save!
  Event.create(user_id: user.id, event_type: :account_created)

  if verified
    user = User.find_by(email_fingerprint: ee.fingerprint)
    profile = Profile.new(user: user)
    pii = Pii::Attributes.new_from_hash(
      first_name: first_name,
      middle_name: middle_name,
      last_name: last_name,
      dob: dob,
      ssn: ssn.rjust(9, '0'),
      address1: address1,
      address2: address2,
      city: city,
      state: state,
      zipcode: zipcode,
      phone: phone
    )
    personal_key = profile.encrypt_pii(pii, password)
    profile.verified_at = Time.zone.now
    profile.activate
  end

  Rails.logger.warn "Account created:"
  account_created = "email=#{email}, password=#{password}, personal_key=#{personal_key}"
  Rails.logger.warn "#{account_created}"
  return account_created
end


# Creates multiple accounts users given a CSV file with attributes
#
# `data` param can be a file path or CSV string, e.g. returned by `File.read('test_accounts.csv')`
# Headers should be:
#   email, password, mfa_phone, verified (true/false), first_name, middle_name, last_name, dob, ssn, address1, address2, city, state, zipcode, phone
def create_accounts_from_csv(data)
  require 'csv'
  accounts_created = []
  users = File.exists?(data) ? CSV.read(data, headers: true) : CSV.parse(data, headers: true)
  users.each do |row|
    email = row['email']
    if User.find_with_email(email).present?
      Rails.logger.warn "user with email #{email} already exists"
      next
    end
    accounts_created.push create_account(
      email: row['email'], password: row['password'], mfa_phone: row['mfa_phone'], verified: row['verified'].downcase == 'true' ? true : false,
      first_name: row['first_name'], middle_name: row['middle_name'], last_name: row['last_name'], dob: row['dob'], ssn: row['ssn'],
      address1: row['address1'], address2: row['address2'], city: row['city'], state: row['state'], zipcode: row['zipcode'], phone: row['phone']
    )
  end

  Rails.logger.warn "\nAccounts created:"
  Rails.logger.warn(puts(accounts_created))
end
