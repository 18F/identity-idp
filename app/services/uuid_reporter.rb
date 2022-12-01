require 'csv'

class UuidReporter
  def self.run(**opts)
    new(**opts).run
  end

  # Instantiate the service object
  #
  # @attr email_file [String] the location of the file with the list of emails
  # @attr sp_file [String] the location of the file with the list of SP issuers
  # @attr output [String] the location where the output CSV should be written
  def initialize(email_file:, sp_file:, output:)
    @emails = parse_file(email_file).map(&:downcase).uniq
    validate_emails
    @issuers = parse_file(sp_file).uniq
    validate_issuers
    @output = output
    validate_output
  end

  # Take the lists of ServiceProvider issuers and emails and do the following:
  #   1. Confirm that the user has an Identity with at least one of the SPs
  #   2. Find the user's associated AgencyIdentity and uuid
  #   3. Export a CSV file with email addresses and associated uuids
  #
  # @return [Integer] the number of uuids collected
  def run
    agency = find_agency
    emails_to_user_ids = collect_user_ids
    emails_to_uuids = collect_identities(agency, emails_to_user_ids)
    save_csv(emails_to_uuids)

    emails_to_uuids.length
  end

  private

  attr_reader :emails, :issuers, :output

  def parse_file(file)
    File.readlines(file, chomp: true)
  rescue Errno::ENOENT
    raise ArgumentError.new("#{file} does not exist")
  end

  def validate_emails
    return if emails.all? { |e| ValidateEmail.valid?(e) }

    raise ArgumentError.new('All of the email addresses must be valid emails')
  end

  def validate_issuers
    all_issuers_belong_to_an_sp?
    all_issuers_belong_to_same_agency?
  end

  def all_issuers_belong_to_an_sp?
    return if ServiceProvider.where(issuer: issuers).count == issuers.length

    raise ArgumentError.new('All of the issuers must correspond to a service provider')
  end

  def all_issuers_belong_to_same_agency?
    agency_count = Agency.
      joins(:service_providers).
      where(service_providers: { issuer: issuers }).
      distinct.
      count

    return if agency_count == 1

    raise ArgumentError.new('All of the issuers must belong to the same agency')
  end

  def validate_output
    return unless File.exist?(@output)

    raise ArgumentError.new('Output file already exists')
  end

  def find_agency
    Agency.
      joins(:service_providers).
      find_by(service_providers: { issuer: issuers.first })
  end

  def collect_user_ids
    emails.each_with_object({}) do |email, hash|
      user_id = EmailAddress.confirmed.find_with_email(email)&.user_id
      hash[email] = user_id
    end
  end

  def collect_identities(agency, emails_to_user_ids)
    # This makes use of the composite indexes on both the identities table
    # (user_id, service_provider) and the agency_identities table (user_id,
    # agency_id) so it should not require a full scan of either table.
    #
    # Note that we use two separate queries since the inner joins don't take
    # advantage of the composite indexes and are highly non-performant.
    actual_user_ids = emails_to_user_ids.values.select(&:present?)
    # mattw: We likely want to change this, but this breaks tests a lot.
    user_ids_with_identities = ServiceProviderIdentity.
      where(user_id: actual_user_ids, service_provider: issuers).
      pluck(:user_id)
    agency_identities = AgencyIdentity.
      select(:uuid, :user_id).
      where(user_id: user_ids_with_identities, agency_id: agency.id)

    uuid_hash = agency_identities.map { |record| [record.user_id, record.uuid] }.to_h
    emails_to_user_ids.transform_values { |user_id| uuid_hash[user_id] }
  end

  def save_csv(emails_to_uuids)
    CSV.open(output, 'w') do |csv|
      csv << ['email_address', 'uuid']

      emails_to_uuids.each do |email, uuid|
        csv << [email, uuid]
      end
    end
  end
end
