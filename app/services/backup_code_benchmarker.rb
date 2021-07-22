# This is for benchmarking backup code conversion to salted hashes
# DO NOT RUN IT IN PRODUCTION
class BackupCodeBenchmarker
  # attribute_cost: "4000$8$4$"
  # scrypt_cost: "10000$8$1$"

  attr_reader :cost
  attr_reader :batch_size
  attr_reader :num_rows
  attr_reader :num_per_user
  attr_reader :logger

  def initialize(
    cost: '10000$8$1$',
    batch_size: 1000,
    num_rows: 100_000, # number of rows to test backfilling
    num_per_user: BackupCodeGenerator::NUMBER_OF_CODES, # defaults to 10
    logger: Logger.new(STDOUT)
  )
    @cost = cost
    @batch_size = batch_size
    @num_rows = num_rows
    @num_per_user = num_per_user
    @logger = logger
  end

  # @yield block to call after rows are created, before they are backfilled
  def run(&before_convert)
    raise 'do not run in prod' if Identity::Hostdata.env == 'prod'

    silence_active_record_logger do
      prepare!
      yield if before_convert
      convert!
    end
  end

  def prepare!
    return if BackupCodeConfiguration.count >= num_rows

    user_id = User.first&.id || 1
    num_to_create = num_rows - BackupCodeConfiguration.count

    generator = BackupCodeGenerator.new(nil)

    logger.info "creating #{num_to_create} backup code configurations"

    num_to_create.times.each_slice(batch_size) do |slice|
      slice.each_slice(num_per_user) do |user_slice|
        user_id += 1

        user_slice.each do
          code = generator.send(:backup_code)

          BackupCodeConfiguration.create(user_id: user_id, code: code)
        end
      end
    end

    logger.info 'done creating backup codes'
  end

  def convert!
    job = BackupCodeBackfillerJob.new

    Benchmark.realtime do
      BackupCodeConfiguration.limit(num_rows).find_in_batches(batch_size: batch_size) do |batch|
        Benchmark.realtime do
          batch.each_slice(num_per_user) do |slice|
            Benchmark.realtime do
              job.perform_batch(slice)
            end.tap do |duration|
              logger.info "duration=#{duration} batch_size=#{slice.size}"
            end
          end
        end.tap do |duration|
          logger.info "duration=#{duration} batch_size=#{batch.size}"
        end
      end
    end.tap do |duration|
      logger.info "duration=#{duration} batch_size=#{num_rows} (done)"
    end
  end

  # @yield a block to run with a silenced AR logger
  def silence_active_record_logger
    ar_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil

    yield
  ensure
    ActiveRecord::Base.logger = ar_logger
  end
end
