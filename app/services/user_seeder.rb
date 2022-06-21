require 'csv'

class UserSeeder
  def self.run(**opts)
    new(**opts).run
  end

  # Instantiate a new instance of the service object
  #
  # @attr csv_file [String] the location of the CSV file with the dummy user data
  # @attr email_domain [String] the domain to use for user emails
  # @attr deploy_env [String] the deploy environment, defaults to
  #   LoginGov::Hostdata but can be overriden for testing
  def initialize(csv_file:, email_domain:, deploy_env: Identity::Hostdata.env)
    @csv_file = csv_file
    file = File.read(csv_file)
    @csv = CSV.parse(file, headers: true)
    validate_csv_headers
    @email_domain = email_domain
    validate_email_domain
    @deploy_env = deploy_env
  rescue Errno::ENOENT
    raise ArgumentError.new("#{csv_file} does not exist")
  end

  # Seed the users whose PII is specified in the CSV file. Raises an
  # ArgumentError if an email address is already taken and uses a transaction to
  # avoid partial completion.
  #
  # @return [Integer] the number of users created
  def run
    validate_environment

    ActiveRecord::Base.transaction do
      @csv.each_with_index do |row, i|
        email = "user#{i}@#{email_domain}"
        row['email_address'] = email
        row['password'] = PASSWORD
        ee = EncryptedAttribute.new_from_decrypted(email)

        user = User.create!
        codes = setup_user(user: user, ee: ee)
        row['codes'] = codes.join('|')

        personal_key = create_profile(user: user, row: row)
        row['personal_key'] = personal_key
      end
    end

    save_updated_csv

    csv.length # the number of saved users
  rescue ActiveRecord::RecordNotUnique
    msg = "email domain #{email_domain} invalid - would overwrite existing users"
    raise ArgumentError.new(msg)
  end

  private

  PASSWORD = 'S00per Seekr3t'.freeze

  PII_ATTRS = %w[
    first_name
    last_name
    dob
    ssn
    phone
    address1
    address2
    city
    state
    zipcode
  ].freeze

  attr_reader :csv_file, :csv, :email_domain, :deploy_env

  def validate_csv_headers
    return if (PII_ATTRS - csv.first.to_h.keys).empty?

    msg = "#{csv_file} must be a CSV file with headers #{PII_ATTRS.join(',')}"
    raise ArgumentError.new(msg)
  end

  def validate_email_domain
    return if ValidateEmail.valid?("user@#{email_domain}")

    raise ArgumentError.new("#{email_domain} is not a valid hostname")
  end

  def validate_environment
    return unless %w[prod staging].include? deploy_env

    raise StandardError.new('This cannot be run in staging or production')
  end

  def setup_user(user:, ee:)
    EmailAddress.create!(user: user, email: ee.decrypted, confirmed_at: Time.zone.now)
    user.reset_password(PASSWORD, PASSWORD)
    Event.create(user_id: user.id, event_type: :account_created)
    generator = BackupCodeGenerator.new(user)
    generator.generate.tap do |codes|
      generator.save(codes)
    end
  end

  def create_profile(user:, row:)
    profile = Profile.new(user: user)
    pii_hash = row.to_h.slice(*PII_ATTRS).transform_keys(&:to_sym)
    pii = Pii::Attributes.new_from_hash(pii_hash)
    personal_key = profile.encrypt_pii(pii, PASSWORD)
    profile.verified_at = Time.zone.now
    profile.activate

    personal_key
  end

  def save_updated_csv
    new_filename = csv_file.gsub('.csv', '-updated.csv')
    CSV.open(new_filename, 'wb') do |new_csv|
      new_csv << @csv.first.to_h.keys
      @csv.each { |row| new_csv << row.to_h.values }
    end
  end
end
