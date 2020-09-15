class VendorProofJob < ApplicationJob
  queue_as :default

  def perform(user_uuid, stage, applicant)
    puts '**' * 20
    puts applicant.inspect
    vendor = Idv::Proofer.get_vendor(stage).new

    result = vendor.proof(applicant)
    puts 'Result ' * 10
    puts result.inspect
    store_result(user_uuid, stage, result)
  end

  def self.get_result(user_uuid, stage)
    json_result = REDIS_POOL.with do |client|
      client.read("#{user_uuid}:#{stage}")
    end

    if json_result
      json = JSON.parse(json_result)
      puts json.inspect
      Proofer::Result.new(errors: json['errors'], messages: Set.new(json['messages']), context: json['context'], exception: json['exception'])
    else
      nil
    end
  end

  private

  def store_result(user_uuid, stage, result)
    puts result.inspect
    puts '@' * 40
    user_id = '2'
    REDIS_POOL.with do |client|
      client.write("#{user_uuid}:#{stage}", result.to_json, expires_in: 120)
    end
  end
end
