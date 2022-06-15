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
  # user.skip_confirmation!
  user.reset_password(password, password)
  user.save!
  MfaContext.new(user).phone_configurations.create(
    phone: mfa_phone || phone,
    confirmed_at: Time.zone.now,
    delivery_preference: user.otp_delivery_preference
  )
  Event.create(user_id: user.id, event_type: :account_created)

  if verified
    # user = User.find_by(email_fingerprint: ee.fingerprint)
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
    generator = BackupCodeGenerator.new(user)
    backup_codes = generator.generate
    generator.save(backup_codes)
    personal_key = profile.encrypt_pii(pii, password)
    profile.verified_at = Time.zone.now
    profile.activate
  end

  puts "Account created:"
  account_created = "email=#{email}, password=#{password}, personal_key=#{personal_key}"
  puts "#{account_created}"
  puts "Backup codes:"
  puts "#{backup_codes}"
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

str = <<~CSV
ID,SSN,FIRST NAME,MI,LAST NAME,DOB,Email,Password,OTPs,Phone Number,ADDRESS,CITY ,STATE ,ZIP
11,057-05-7728,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
12,126-14-2626,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
13,102-26-8826,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
14,099-48-9126,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
15,099-94-0625,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
16,066-98-3029,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
17,077-92-1128,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
18,001-68-9127,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
19,043-88-1525,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
20,109-52-1529,MARION,R,BRIEN,3/1/1941,,,,412-462-9823,350 LEHIGH AVE,PITTSBURGH,PA,15232-2008
21,066-40-2008,GAIL,S,VVICTORY,6/9/1951,,,,(443) 421-8935,13 NESBIT PLACE,ALPHARETTA,GA,30022
CSV

csv = CSV.parse(str, headers: true)
csv.each do |row|
  create_account(
    email: "ssa-test-#{row['ID']}@ssa.gov",
    mfa_phone: row['Phone Number'],
    first_name: row['FIRST NAME'],
    last_name: row['LAST NAME'],
    dob: row['DOB'],
    ssn: row['SSN'],
    address1: row['ADDRESS'],
    city: row['CITY'],
    state: row['STATE'],
    zipcode: row['ZIP'],
    phone: row['Phone Number']
  )
end
