namespace :users do
  desc 'Finds all verified users NOT present in a CSV file'
  task verified_but_not_in_csv: :environment do |t|
    DEFAULT_WINDOW_IN_SECONDS = 60
    DEFAULT_EXTRA_ATTRIBUTES = 'created_at,activated_at'

    if STDIN.tty?
      puts <<~HOWTOUSE
        This task requires CSV data be piped into it, for example:

        $ bundle exec rake #{t.name} < my_csv_file.csv

        Your data should have two columns, a user id (UUID) and a timestamp (formatted as something 
        DateTime can parse). You don't need to have headers in your file.

        This task will output UUIDs for _active_ users that:

        - Do not appear in the CSV file
        - Appear in the CSV file, but the associated timestamp is within a window of the 
          Profile's creation timestamp (set WINDOW_IN_SECONDS to control this behavior,
          the default is #{DEFAULT_WINDOW_IN_SECONDS}).

      HOWTOUSE
      exit 1
    end

    batch_size = ENV['BATCH_SIZE'] || 100
    window_in_seconds = ENV['WINDOW_IN_SECONDS'].nil? ?
      DEFAULT_WINDOW_IN_SECONDS :
      ENV['WINDOW_IN_SECONDS']
    timestamp_column_index = ENV['TIMESTAMP_COLUMN_INDEX']
    user_id_column_index = ENV['USER_ID_COLUMN_INDEX']
    extra_attributes = (ENV['EXTRA_ATTRIBUTES'] || DEFAULT_EXTRA_ATTRIBUTES).split(',')

    timestamps_by_user_id = build_user_id_timestamp_index(
      csv: CSV.new(STDIN),
      user_id_column_index:,
      timestamp_column_index:,
    )

    profiles = Profile.where(active: true).includes(:user)
    est_batches = (profiles.length.to_f / batch_size).ceil
    progress = ProgressBar.create(
      format: '%t: |%B| %j%% [%a / %e]',
      output: STDERR,
      title: 'Profiles',
      total: est_batches * batch_size,
    )

    output = CSV.new(STDOUT)
    output_headers = false

    find_profiles_not_in_index(
      profiles:,
      timestamps_by_user_id:,
      batch_size:,
      window_in_seconds:,
    ) do |uuid, profile, closest_timestamp|
      if !output_headers
        output_headers = true
        output << ['uuid', 'closest_timestamp', *extra_attributes]
      end

      output << [uuid, closest_timestamp, *profile.values_at(extra_attributes)]

      progress.increment
    end
  end

  def build_user_id_timestamp_index(csv:, user_id_column_index:, timestamp_column_index:)
    timestamps_by_user_id = {}

    csv.each.with_index do |row, index|
      # We may or may not have headers in column output. Try and discover a user id and
      # timestamp in the first couple of rows to figure out which is which.
      if user_id_column_index.nil? && timestamp_column_index.nil?
        user_id_column_index = discover_user_id_column_index(row)
        timestamp_column_index = discover_timestamp_column_index(row)
      end

      if user_id_column_index.nil? || timestamp_column_index.nil?
        if index < 2
          next
        else
          raise 'Could not identify user id and timestamp columns'
        end
      end

      timestamp = DateTime.parse(row[timestamp_column_index])
      user_id = row[user_id_column_index]
      timestamps_by_user_id[user_id] ||= []
      timestamps_by_user_id[user_id] << timestamp
    end

    timestamps_by_user_id
  end

  def discover_timestamp_column_index(row)
    candidates = row.map.with_index do |value, index|
      index if DateTime.parse(value)
    rescue Date::Error
    end.filter

    candidates.first
  end

  def discover_user_id_column_index(row)
    uuid_regex = /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/i
    candidates = row.map.with_index do |value, index|
      index if uuid_regex.match(value)
    end.filter(&:present?)

    candidates.first
  end

  def find_profiles_not_in_index(
    batch_size:,
    profiles:,
    timestamps_by_user_id:,
    window_in_seconds:
  )
    profiles.find_in_batches(batch_size:) do |profiles|
      profiles.each do |profile|
        uuid = profile.user.uuid

        closest_timestamp = timestamps_by_user_id[uuid]&.sort_by do |timestamp|
          (profile.created_at - timestamp).abs
        end&.first

        timestamp_in_window = closest_timestamp.present? &&
                              (profile.created_at - closest_timestamp).abs <= window_in_seconds

        yield uuid, profile, closest_timestamp if !timestamp_in_window
      end
    end
  end
end
