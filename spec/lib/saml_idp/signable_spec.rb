# encoding: utf-8
require 'spec_helper'
class MockSignable
  include SamlIdp::Signable

  def raw
    builder = Builder::XmlMarkup.new
    builder.body do |body|
      sign body
    end
  end

  def reference_id
    "abc"
  end

  def digest
    algorithm.digest raw
  end

  def algorithm
    OpenSSL::Digest::SHA1
  end
end

module SamlIdp
  describe MockSignable do
    let(:signature_regex) { %r{<ds:Signature xmlns:ds=\"http:\/\/www.w3.org\/2000\/09\/xmldsig#\">} }
    let(:info_regex) { %r{<ds:SignedInfo xmlns:ds=\"http:\/\/www.w3.org\/2000\/09\/xmldsig#\">} }
    let(:canon) do
      %r{<ds:CanonicalizationMethod Algorithm=\"http:\/\/www.w3.org\/2001\/10\/xml-exc-c14n#\"><\/ds:CanonicalizationMethod>}
    end
    let(:sig_method) do
      %r{<ds:SignatureMethod Algorithm=\"http:\/\/www.w3.org\/2000\/09\/xmldsig#rsa-sha1\"><\/ds:SignatureMethod>}
    end
    let(:reference) { %r{<ds:Reference URI=\"#_abc\">} }
    let(:transforms) { %r{<ds:Transforms>} }
    let(:enveloped) { %r{<ds:Transform Algorithm=\"http:\/\/www.w3.org\/2000\/09\/xmldsig#enveloped-signature\"><\/ds:Transform>} }
    let(:c14n) { %r{<ds:Transform Algorithm=\"http:\/\/www.w3.org\/2001\/10\/xml-exc-c14n#\"><\/ds:Transform>} }
    let(:end_transforms) { %r{<\/ds:Transforms>} }
    let(:digest_method) { %r{<ds:DigestMethod Algorithm=\"http:\/\/www.w3.org\/2000\/09\/xmldsig#sha1\"><\/ds:DigestMethod>} }
    let(:digest_value) { %r{<ds:DigestValue>\S+<\/ds:DigestValue>} }
    let(:end_reference) { %r{<\/ds:Reference>} }
    let(:end_info) { %r{<\/ds:SignedInfo>} }
    let(:sig_val) { %r{<ds:SignatureValue>\S+<\/ds:SignatureValue>} }
    let(:key_info) { %r{<KeyInfo xmlns=\"http:\/\/www.w3.org\/2000\/09\/xmldsig#\">} }
    let(:x509) { %r{<ds:X509Data><ds:X509Certificate>\S+<\/ds:X509Certificate><\/ds:X509Data>} }
    let(:end_rest) { %r{<\/KeyInfo><\/ds:Signature>} }

    let(:all_regex) do
      Regexp.new [
        signature_regex,
        info_regex,
        canon,
        sig_method,
        reference,
        transforms,
        enveloped,
        c14n,
        end_transforms,
        digest_method,
        digest_value,
        end_reference,
        end_info,
        sig_val,
        key_info,
        x509,
        end_rest,
      ].map(&:to_s).join(".*")
    end

    its(:signed) { should match all_regex }
  end
end
