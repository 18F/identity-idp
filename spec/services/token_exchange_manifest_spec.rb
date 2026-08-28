require 'rails_helper'

RSpec.describe TokenExchangeManifest do
  let(:broker) { 'urn:gov:gsa:openidconnect:sp:token_exchange_broker' }
  let(:manifest_url) { 'https://broker.example.gov/.well-known/services' }
  let(:kid) { 'broker-2026' }
  let(:signing_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:audience) { Rails.application.routes.url_helpers.root_url }

  let(:claims) do
    now = Time.zone.now.to_i
    {
      iss: broker,
      aud: audience,
      iat: now,
      nbf: now,
      exp: now + 2 * 60 * 60,
      services: [{ issuer: 'target.gov' }, { issuer: 'other.gov' }],
    }
  end

  def jws(claims_hash, key: signing_key, header_kid: kid, algorithm: 'RS256')
    JWT.encode(claims_hash, key, algorithm, kid: header_kid)
  end

  let(:manifest_body) { jws(claims) }

  before do
    Rails.cache.clear
    allow(IdentityConfig.store).to receive(:token_exchange_manifest_urls)
      .and_return({ broker => manifest_url })
    allow(IdentityConfig.store).to receive(:token_exchange_manifest_public_keys)
      .and_return({ broker => { kid => signing_key.public_key.to_pem } })
  end

  describe '.allowed_targets' do
    it 'returns issuers from a validly signed broker manifest' do
      stub_request(:get, manifest_url).to_return(body: manifest_body)

      expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])
    end

    it 'rejects a manifest signed by the wrong key' do
      body = jws(claims, key: OpenSSL::PKey::RSA.new(2048))
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects a manifest whose kid is not configured' do
      body = jws(claims, header_kid: 'rotated-out')
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects an unsigned (alg=none) manifest' do
      body = JWT.encode(claims, nil, 'none', kid: kid)
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects a manifest whose iss is not the requested broker' do
      body = jws(claims.merge(iss: 'urn:evil'))
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects a manifest addressed to a different audience (replay)' do
      body = jws(claims.merge(aud: 'https://some-other-idp.example'))
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects an expired manifest' do
      body = jws(claims.merge(exp: Time.zone.now.to_i - 3600, nbf: Time.zone.now.to_i - 7200))
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects a not-yet-valid manifest' do
      body = jws(claims.merge(nbf: Time.zone.now.to_i + 3600))
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects a manifest with no exp claim' do
      body = jws(claims.except(:exp))
      stub_request(:get, manifest_url).to_return(body: body)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'rejects a manifest missing iss or aud' do
      stub_request(:get, manifest_url).to_return(body: jws(claims.except(:iss)))
      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'does not cache a verification failure (no TTL poisoning)' do
      stub_request(:get, manifest_url).to_return(body: jws(claims, key: OpenSSL::PKey::RSA.new(2048)))
      expect(described_class.allowed_targets(broker)).to eq([])

      stub_request(:get, manifest_url).to_return(body: manifest_body)
      expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])
    end

    it 'verifies against the key selected by kid during rotation' do
      old_key = OpenSSL::PKey::RSA.new(2048)
      allow(IdentityConfig.store).to receive(:token_exchange_manifest_public_keys)
        .and_return(
          {
            broker => {
              'broker-2025' => old_key.public_key.to_pem,
              kid => signing_key.public_key.to_pem,
            },
          },
        )
      stub_request(:get, manifest_url).to_return(body: manifest_body)

      expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])
    end

    it 'serves cached targets without refetching inside the trust window' do
      req = stub_request(:get, manifest_url).to_return(body: manifest_body)

      described_class.allowed_targets(broker)
      described_class.allowed_targets(broker)

      expect(req).to have_been_requested.once
    end

    it 'refetches once the cache TTL has elapsed' do
      stub_request(:get, manifest_url).to_return(body: manifest_body)

      described_class.allowed_targets(broker)
      travel(described_class::CACHE_TTL + 1.minute) do
        described_class.allowed_targets(broker)
      end

      expect(a_request(:get, manifest_url)).to have_been_made.twice
    end

    it 'stops serving once the manifest exp passes, even inside the cache TTL' do
      short = jws(claims.merge(exp: Time.zone.now.to_i + 5 * 60))
      stub_request(:get, manifest_url).to_return(body: short, headers: { 'ETag' => 'v1' })

      expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])

      # Past exp (5m) but inside CACHE_TTL (15m); broker still 304s the unchanged
      # body. exp must still be enforced -> fail closed.
      stub_request(:get, manifest_url)
        .with(headers: { 'If-None-Match' => 'v1' }).to_return(status: 304)
      allow(NewRelic::Agent).to receive(:notice_error)

      travel(6.minutes) do
        expect(described_class.allowed_targets(broker)).to eq([])
      end
    end

    it 're-verifies (does not send validators) once the cached copy is past exp' do
      short = jws(claims.merge(exp: Time.zone.now.to_i + 5 * 60))
      stub_request(:get, manifest_url).to_return(body: short, headers: { 'ETag' => 'v1' })
      described_class.allowed_targets(broker)

      travel(6.minutes) do
        fresh = jws(claims.merge(exp: Time.zone.now.to_i + 2 * 60 * 60))
        stub_request(:get, manifest_url).to_return(body: fresh, headers: { 'ETag' => 'v2' })

        expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])
        # Past exp: must NOT revalidate with the stale validator, must re-download.
        expect(a_request(:get, manifest_url).with(headers: { 'If-None-Match' => 'v1' }))
          .not_to have_been_made
      end
    end

    it 'fails closed when the broker is unreachable past the trust window' do
      stub_request(:get, manifest_url).to_return(body: manifest_body)
      described_class.allowed_targets(broker)

      stub_request(:get, manifest_url).to_return(status: 500)
      allow(NewRelic::Agent).to receive(:notice_error)

      travel(described_class::CACHE_TTL + 1.minute) do
        expect(described_class.allowed_targets(broker)).to eq([])
      end
    end

    it 'serves cached targets within the window even if the broker starts failing' do
      stub_request(:get, manifest_url).to_return(body: manifest_body)
      described_class.allowed_targets(broker)

      stub_request(:get, manifest_url).to_return(status: 500)
      allow(NewRelic::Agent).to receive(:notice_error)

      # Still inside CACHE_TTL: served from cache, broker is never re-hit.
      expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])
    end

    it 'honors a 304 while the cached manifest is still within exp' do
      stub_request(:get, manifest_url).to_return(body: manifest_body, headers: { 'ETag' => 'v1' })
      described_class.allowed_targets(broker)

      conditional = stub_request(:get, manifest_url)
        .with(headers: { 'If-None-Match' => 'v1' }).to_return(status: 304)

      travel(described_class::CACHE_TTL + 1.minute) do
        expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])
      end
      expect(conditional).to have_been_requested
    end

    it 'fails closed on a 304 with no cached entry' do
      stub_request(:get, manifest_url).to_return(status: 304)
      allow(NewRelic::Agent).to receive(:notice_error)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'returns empty for an unconfigured broker' do
      expect(described_class.allowed_targets('unknown')).to eq([])
    end

    it 'returns empty when no verification key is configured' do
      allow(IdentityConfig.store).to receive(:token_exchange_manifest_public_keys)
        .and_return({})
      req = stub_request(:get, manifest_url).to_return(body: manifest_body)

      expect(described_class.allowed_targets(broker)).to eq([])
      expect(req).not_to have_been_requested
    end

    it 'returns empty and swallows fetch failures with no cache' do
      stub_request(:get, manifest_url).to_return(status: 500)
      allow(NewRelic::Agent).to receive(:notice_error)

      expect(described_class.allowed_targets(broker)).to eq([])
    end

    it 'refuses to fetch a non-https manifest url' do
      allow(IdentityConfig.store).to receive(:token_exchange_manifest_urls)
        .and_return({ broker => 'http://broker.example.gov/manifest' })
      req = stub_request(:get, 'http://broker.example.gov/manifest')

      expect(described_class.allowed_targets(broker)).to eq([])
      expect(req).not_to have_been_requested
    end

    it 'allows plain http for loopback hosts (local development)' do
      loopback = 'http://localhost:8788/.well-known/services'
      allow(IdentityConfig.store).to receive(:token_exchange_manifest_urls)
        .and_return({ broker => loopback })
      stub_request(:get, loopback).to_return(body: manifest_body)

      expect(described_class.allowed_targets(broker)).to eq(%w[target.gov other.gov])
    end
  end
end
