require 'csv'

class UserIdToAgencyUuidReporter
  include ActiveModel::Model

  def self.run(**opts)
    new(**opts).run
  end

  validate :sp_exists
  validate :output_file_does_not_exist

  # Instantiate a new instance of the service object
  #
  # @attr issuer [String] the SP issuer to run the report for
  # @attr output [String] the location where the output CSV should be written
  def initialize(issuer:, output:)
    @issuer = issuer
    @sp = ServiceProvider.find_by(issuer: issuer)
    @agency_id = sp&.agency_id
    @output = output

    raise ArgumentError.new(errors.full_messages.join('; ')) unless valid?
  end

  def run
    rows = collect_sp_identity_info
    rows = collect_agency_uuids(rows)
    save_csv(rows)

    rows.length
  end

  private

  attr_reader :agency_id, :issuer, :output, :sp

  def sp_exists
    return if sp

    errors.add(:issuer, 'must correspond to a service provider')
  end

  def output_file_does_not_exist
    return unless File.exist?(output)

    errors.add(:output, 'already exists')
  end

  def collect_sp_identity_info
    Hash.new.tap do |records|
      ServiceProviderIdentity.
        select(:id, :service_provider, :user_id, :created_at).
        find_in_batches(batch_size: 10_000) do |batch|
          batch.each do |sp_identity|
            if sp_identity.service_provider == issuer
              records[sp_identity.user_id] = { created_at: sp_identity.created_at }
            end
          end
        end
    end
  end

  def collect_agency_uuids(rows)
    user_ids = rows.keys
    agency_identities = AgencyIdentity.
      select(:user_id, :uuid).
      where(user_id: user_ids, agency_id: agency_id)
    uuid_hash = agency_identities.map { |record| [record.user_id, record.uuid] }.to_h

    rows.map do |user_id, row|
      [user_id, row.merge({uuid: uuid_hash[user_id] })]
    end.to_h
  end

  def save_csv(rows)
    CSV.open(output, 'w') do |csv|
      csv << ['old_identifier', 'new_identifier', 'created_at']

      rows.each do |user_id, row|
        csv << [user_id, row[:uuid], row[:created_at]]
      end
    end
  end
end
