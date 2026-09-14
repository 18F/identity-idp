# frozen_string_literal: true

# Wraps individual db/seeds.rb seeder calls with logging so failures are visible
# without halting the rest of the seeding process.
class SeedRunner
  def initialize(logger: Rails.logger)
    @logger = logger
    @failed_seeders = []
  end

  def run(seeder, name: seeder.class.name)
    logger.info("[db:seed] Starting #{name}")
    started_at = Time.zone.now
    yield seeder
    duration = Time.zone.now - started_at
    logger.info("[db:seed] #{name} succeeded (#{duration.round(2)}s)")
  rescue StandardError => e
    logger.error("[db:seed] #{name} failed: #{e.class}: #{e.message}")
    failed_seeders << name
  end

  # Logs a final summary and raises if any seeder failed.
  def finish!
    if failed_seeders.any?
      logger.error("[db:seed] Seeding completed with failures: #{failed_seeders.join(', ')}")
      raise "db:seed failed for: #{failed_seeders.join(', ')}"
    else
      logger.info('[db:seed] Seeding completed: all seeders succeeded')
    end
  end

  private

  attr_reader :logger, :failed_seeders
end
