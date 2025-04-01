# frozen_string_literal: true

class RemoveIntegrationFromOrder
  attr_reader :iaa_gtc_number, :order_number, :issuer, :stdin, :stdout

  def initialize(iaa_gtc_number, order_number, mod_number, issuer, stdin: STDIN, stdout: STDOUT)
    @stdin = stdin
    @stdout = stdout
    @iaa_gtc_number = iaa_gtc_number
    @order_number = order_number
    @mod_number = mod_number
    @issuer = issuer
  end

  def run
    validate_inputs
    print_data
    confirm_deletion
    remove_integration
  end

  private

  def validate_inputs
    unless iaa_gtc
      raise ArgumentError, "No IAA GTC found with number #{iaa_gtc_number}"
    end

    unless integration
      raise ArgumentError, "No integration found for issuer #{issuer}"
    end

    unless integration_usage
      raise ArgumentError, 'No integration usage found for this combination'
    end
  end

  def print_data
    stdout.puts "You are about to remove integration #{issuer} from IAA order:"
    stdout.puts "GTC: #{iaa_gtc_number}"
    stdout.puts "Order: #{order_number}"
    stdout.puts "\nIntegration details:"
    stdout.puts integration.attributes.to_yaml
    stdout.puts "\nIAA Order details:"
    stdout.puts iaa_order.attributes.to_yaml
    stdout.puts "\n"
  end

  def confirm_deletion
    stdout.puts "Type 'yes' and hit enter to continue and remove this integration usage:\n"
    continue = stdin.gets.chomp

    unless continue == 'yes'
      stdout.puts 'You have indicated there is an issue. Aborting script'
      exit 1
    end
  end

  def remove_integration
    stdout.puts 'Removing integration usage...'
    integration_usage.destroy!
    stdout.puts "Successfully removed integration #{issuer} from IAA order #{iaa_gtc_number}-#{order_number}"
  end

  def iaa_gtc
    @iaa_gtc ||= IaaGtc.find_by(gtc_number: iaa_gtc_number)
  end

  def iaa_order
    @iaa_order ||= IaaOrder.includes(:iaa_gtc).find_by(
      iaa_gtc: iaa_gtc,
      order_number: order_number,
      mod_number: mod_number,
    )
  end

  def integration
    @integration ||= Integration.find_by(issuer: issuer)
  end

  def integration_usage
    @integration_usage ||= IntegrationUsage.find_by(
      iaa_order: iaa_order,
      integration: integration,
      mod_number: mod_number,
    )
  end
end
