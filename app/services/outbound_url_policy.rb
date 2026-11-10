# frozen_string_literal: true

require 'ipaddr'

# Decides whether the application may send an HTTP request to an address that a partner or an
# operator supplied: a partner's RISC push notification URL (RFC 8935), a proofing agent's result
# webhook, or the endpoints a document-verification webhook is repeated to. Those URLs are checked
# for shape when they are stored, not for where they point, so without this check a URL could aim
# a request from the application's own network position at an internal service, at the cloud
# metadata address or at the host itself (server-side request forgery). A request is allowed only
# when the scheme is https and a host given as a literal address is a public one.
#
# Host names are not resolved here. Resolving would add a name-server round trip and its failure
# modes to every webhook, and what a name resolves to at check time need not be what the request
# connects to a moment later; the literal-address and scheme rules are the part that holds. Outside
# production the reference applications run on localhost over http, so the scheme and loopback
# checks are relaxed there; private, link-local and unspecified addresses are refused everywhere.
class OutboundUrlPolicy
  class RefusedError < StandardError; end

  # Never a partner's service: RFC 1918 and RFC 6598 private space, link-local (which includes
  # the cloud metadata service at 169.254.169.254), the unspecified network, and the IPv6
  # unique-local, link-local and unspecified addresses. IPv4-mapped IPv6 addresses are checked as
  # the IPv4 address they carry.
  BLOCKED_RANGES = %w[
    10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 0.0.0.0/8
    fc00::/7 fe80::/10 ::/128
  ].map { |cidr| IPAddr.new(cidr) }.freeze

  LOOPBACK_RANGES = %w[127.0.0.0/8 ::1/128].map { |cidr| IPAddr.new(cidr) }.freeze

  Decision = Struct.new(:allowed, :reason, keyword_init: true) do
    def allowed?
      allowed
    end
  end

  # @param url [String] the address a request is about to be sent to
  # @param production [Boolean] whether the https and loopback rules apply
  # @return [Decision] allowed, or refused with a reason symbol: :malformed, :scheme, :host,
  #   :loopback_address or :private_address
  def self.decide(url, production: Rails.env.production?)
    new(url, production:).decide
  end

  def self.allowed?(url, production: Rails.env.production?)
    decide(url, production:).allowed?
  end

  def initialize(url, production:)
    @url = url.to_s
    @production = production
  end

  def decide
    uri = URI.parse(url)
    return refuse(:scheme) unless uri.is_a?(URI::HTTP)
    return refuse(:scheme) if production && !uri.is_a?(URI::HTTPS)
    return refuse(:host) if uri.host.blank?

    addresses = addresses_for(uri.host)
    return refuse(:private_address) if addresses.any? { |address| blocked?(address) }
    if production && addresses.any? { |address| loopback?(address) }
      return refuse(:loopback_address)
    end

    Decision.new(allowed: true, reason: nil)
  rescue URI::InvalidURIError
    refuse(:malformed)
  end

  private

  attr_reader :url, :production

  def refuse(reason)
    Decision.new(allowed: false, reason:)
  end

  # The host as an address when it is written as one (IPv6 literals arrive in brackets); a host
  # name yields no address and is judged by scheme alone.
  def addresses_for(host)
    parsed = IPAddr.new(host.delete_prefix('[').delete_suffix(']'))
    [parsed.ipv4_mapped? ? parsed.native : parsed]
  rescue IPAddr::InvalidAddressError
    []
  end

  def blocked?(address)
    BLOCKED_RANGES.any? { |range| range.include?(address) }
  end

  def loopback?(address)
    LOOPBACK_RANGES.any? { |range| range.include?(address) }
  end
end
