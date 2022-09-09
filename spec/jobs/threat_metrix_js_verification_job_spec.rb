require 'rails_helper'

RSpec.describe ThreatMetrixJsVerificationJob, type: :job do
  let(:proofing_device_profiling_collecting_enabled) { true }
  let(:threatmetrix_org_id) { 'ABCD1234' }
  let(:threatmetrix_session_id) { 'some-session-id' }
  let(:threatmetrix_signing_certificate) do
    <<~END
      -----BEGIN CERTIFICATE-----
      MIIEqjCCApICCQC8hXt9uhVWFjANBgkqhkiG9w0BAQsFADAXMRUwEwYDVQQDDAxz
      aWduaW5nLXRlc3QwHhcNMjIwOTA5MTYwMDAxWhcNMzIwOTA2MTYwMDAxWjAXMRUw
      EwYDVQQDDAxzaWduaW5nLXRlc3QwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
      AoICAQDTpZRdHAmkpi0EoeNB9x/FVmsc5WxETvMKvOB06O7CDYrf9SZklXjq8R8N
      uT7el+BoM+6auVeTD+uYbyasUSGjWB83BH16q85Oy1YQxpGZitSuQctRdgs8Idsb
      TvP9csREbC6GMlsqcgh1Qe07565SYyVF/DruwqKL28p5RtCPTtgkfxVl7Nnf8IMp
      d1ILtTpzlYzbnSKvkXZwx1PSrXsviXhoYxlzTfbIOMDvCCEAhspGdOPHJJAT6dd4
      iSVsLpHwyEG6pDlEIZlcE43S7tyVLiTDMORiSEYxbbLJhNWb8o+g0rOs/w3wnn/O
      w5PdFImeGGCpH/5dBraiKR/kGdw48BNzvU0yhdZfYe4jtKZJSQ3140n8EypCXMaR
      jl/dHMl/BcW4a3nMS+t768yL7pA1lvFs6gpf4fFxySHsZq0C3EiO6nWTOD1zg0qR
      sfSwVZLVZF5PQNkXqDMG7gBPWGqHx6qtUtE95w3m0BC99dFekKsgH3AhFKjzoI/e
      bB7o82am48cEWKxBzjllIaEFI+g9zHhqgZX677zMGi2MxCGiznFTRaT5ZUDSBBxa
      F1Vba86He7PgU35925cL1MbbaSJ8LTpC3Clr2MfQAsXtZ4HjCxpriKgid0sxur/L
      OWB7ZTe1hgmim9dWEaRqqELMyTZYcidjWdyljOGqXfDyde1DVQIDAQABMA0GCSqG
      SIb3DQEBCwUAA4ICAQCegU8gVLeIDvvhDmJdx5IxDqtic820wFE9s4BT7N73Ik3f
      ywwIHbSR5BSWaIyaKYKzZ5iouJxNZ4IppFYnYPVWrWGqm96V1yMhDpS2hnbsrZaA
      EirY5DqXga9pfxDNb83gD4FD2tZoK75fzVgwdqnBlzOaGXy4Dgf9yef5Ok1jy/+p
      750nh2uXClF6yRtB1bxUnOt54LbWInoFr+S/hDR3WJlmF33bjOEliDZ1h1R/i7I9
      E7vchrzDc0HqiRvkUvHoE0lZX38d6l2Lb/agctVgIeKC+6p8hOdUa4dCseAcOkwV
      FPUOWsyPnauDiKc3EKN9pUPdmn9BD9vVl5FuTTUkQPZF9dbnV392JU7nHBn8DGgo
      99QyeXA3+qaEqVSbTYWtBqLtWyhyr/OaB+Y2TmP4c+Hdr/8pydIUluMF594e4BUz
      L4GLfB4bdbqw6SKTAQIASq4Dlj0vLlp1U0axPzz1eH8TEtRSF5XOmjXLlI1SlaJB
      4RpVU19RifIdFR3wSMe2Tv+SVjvbNhCRcH/glTDjownThbK73Uy9K5EbFCcxDGzm
      k2Tzqgpbs3GNpq4BdBSxA2UExosz5EAbcxhEI2/YiH6378F/cWLepGjCVPmuHm3r
      XemyOx/wRbYuSXPibNE3/Qw8xi9b4voyyJPPWUus+qJpgQCuMkH9UiOx65e/2g==
      -----END CERTIFICATE-----
    END
  end

  let(:threatmetrix_private_key) do
    <<~END
      -----BEGIN PRIVATE KEY-----
      MIIJRAIBADANBgkqhkiG9w0BAQEFAASCCS4wggkqAgEAAoICAQDTpZRdHAmkpi0E
      oeNB9x/FVmsc5WxETvMKvOB06O7CDYrf9SZklXjq8R8NuT7el+BoM+6auVeTD+uY
      byasUSGjWB83BH16q85Oy1YQxpGZitSuQctRdgs8IdsbTvP9csREbC6GMlsqcgh1
      Qe07565SYyVF/DruwqKL28p5RtCPTtgkfxVl7Nnf8IMpd1ILtTpzlYzbnSKvkXZw
      x1PSrXsviXhoYxlzTfbIOMDvCCEAhspGdOPHJJAT6dd4iSVsLpHwyEG6pDlEIZlc
      E43S7tyVLiTDMORiSEYxbbLJhNWb8o+g0rOs/w3wnn/Ow5PdFImeGGCpH/5dBrai
      KR/kGdw48BNzvU0yhdZfYe4jtKZJSQ3140n8EypCXMaRjl/dHMl/BcW4a3nMS+t7
      68yL7pA1lvFs6gpf4fFxySHsZq0C3EiO6nWTOD1zg0qRsfSwVZLVZF5PQNkXqDMG
      7gBPWGqHx6qtUtE95w3m0BC99dFekKsgH3AhFKjzoI/ebB7o82am48cEWKxBzjll
      IaEFI+g9zHhqgZX677zMGi2MxCGiznFTRaT5ZUDSBBxaF1Vba86He7PgU35925cL
      1MbbaSJ8LTpC3Clr2MfQAsXtZ4HjCxpriKgid0sxur/LOWB7ZTe1hgmim9dWEaRq
      qELMyTZYcidjWdyljOGqXfDyde1DVQIDAQABAoICABSd3IX1ZTsUtO3ulySl3gJr
      GKQH9TPyPNqe63538koU56JJTyQdK1o3gr7jfKxSPxnndSa9RzqcImcG7M18Wbp/
      qwrA9Tgt5Dros8mOjkBWtcEDx7p3tUB2S9GtLzdRJq1DnISWAytvUEOb2HAtcV21
      KrxWhaccbpkRH/gQXeCX3ZYwivUSzWZzF1PCu8tILBl2R/JcrDROByuVPyUWoRlQ
      WtpQTPpebduzK5gdQpm6h5m1aTrM5PwLm2GyemK/Zpf96ek0dh+c5kOB5B7YBcTC
      afJZoOWyBKRr+y6GMgiu6C7SV45SihkWV3zcsFqo1X8BAOl4pF6LeN7zAphFrJ3x
      yDB51xXEOakNJ2N9Rd5ZETxYj0Q8WmfG8FmC46vFdqdgEdmjcAXxtOqbCnVDFY3R
      o7rvKe4JVbAilE7UtiTj8vmSAWDVm54DwQ3XmAMpo8djAAF8auA2pHGsqSuHvSfn
      jbFIwTJyfflnfnCPeOBsmJW/NFJ2PfV15HqVQahdU11AUiq92iFySBI1AvPyUV0/
      +sp01MZSCbcIyFz+o3WVS4tBQ4t2e15OuXnYdImVLVcdeEXIPsxCPtKN0HNpT252
      DXeaP9OJmwtipHhQyN4sSv+pzU3Jg3R1cqWdJ3b/gqvlWrh6wvt0ZabRR6pT8C4Z
      J2l2maKAruSKi16H7OQBAoIBAQD7quOGaYHD/18bellREKf6/xUHc46fnMNkq0R1
      XteRdroPFvq9jmYxe9Dph8HAJTNY6hlU4RjeAYsBhkflRcg6jYP7NlYBqELgwN8g
      wb2gfVHGWd+q0a1rxInKP4s0uSLUyvF3KUaoavUALtRdmX8VLXe4lwAL7clbRNEd
      nVDhLp9yTAD9sYAqezsNXIZvRU4vZJT0JmXUFFyVxawBZfgdGQL5d7ainR7+EuYu
      dRAiWMWyiNIhx7Bw2jXWZXPcpEK++90nvvzGYTXX8shHtOV5MsPKGV6or77CKS/w
      dVroLDcKD95eqqz8eEGlqW2SJXeWuKt4euX9qK6a+Q6VnrXxAoIBAQDXSlFBflUy
      JL6O75goLoHos42y822ghP1PrjXeuyP5lPs69tpW6mGK7El8nK1oXsg1oCpnaYzR
      vh5EiueDIOi+SZQJwV7wJgwWtJ7453L2P9GfAQxH5i/KChCqDhJg8EkrwJUabw4x
      yZr56e4raKOYAHN6VYiM4nms1Z6PdX+7IcpX1vXhhV75+kuPP6T9kP0Ii2VJdOji
      jcQb2TXQMET34E/IsjQ+MfF+/OsrqvWQZoHVYhpdKNPKiKxsnaqGmsjuFhH8nn4X
      lyn6tdVax+ZD5y0BZ/bcrDZNov69zrrV1xEW+n65096ueLP10+8cVrtFE4FsfFSj
      sq2/w45pJu+lAoIBAQDlpv+Q/F5qGHMVhARVMTnYlUT/U7fmdwrmplMGN9HG7+zB
      MFsG9xbSOQZe1H89c7TzgkwzZGVo0Uej0IFy+sbIh7LUXrUFNiIxLk9ueN0twq4I
      rqKoIkZ6fRKv+GRzbC4YuEi4UHYl4dRIonMwJo4NKTyCuWhVeluwaY/Z0mCn2/+s
      MScGWh92pJUykCgtCbVbEhHK6e8qJJqIIaXgcMiE5PoN4+xJX8+UUnKyGijq7s8Z
      KDl4kdy0XquaRWIBCfPOi884IdRQwwx7TxTsOmrcujJoDdaPYDBWxXb1mmGmVBK1
      n91vzZelm6dsILvYDVCfvUzb2GpfmroauQNSDU5BAoIBAQCv3Q55QJiZqHhdTIzv
      reYCz8Gdf8p6iIhgMX/h3N8rPq7m4MVEoJtjn1b8SwRAMMS9QYPCC++zWelhtlId
      xKE65+HdAi/qXjobxhniWzaGv2UdzP5aMUeyc/xe3bXXqBEtg1iJSlS/CN/m7FfY
      79ZLEXtDYGF2LH6WV735lFLt61Fd5cPfIFKQQwy8DJJba7e25h+sHKssff/He+zA
      jt2X2o1x9VhFwghy4mm8tx93gLToOQYuOW6gkHrBEx48bG5cRn0U7ec0oA/zs9uA
      F7EaoNobvvBiHO8TBmWvaRMoIVHdgmxIojDSNtlSo3g8nwDFEYT0uK9vNUNHVZic
      fujdAoIBAQDB1mUAzUvWGu+4/tvnUrE4OobQasmx98wSIM8wWfrM6gPa20b2f5J2
      eoMSGwDFZp/9Y7CyRWNoQmT81BJJ+DJA8XzQOlDRrr+9AmjLb6eecTBEPlZ+jvMs
      NGdDmL9pkhOMcvloI43vtRlGkevQ+CM+CSsQQPKUuazXrnzwUsCEW34GxfKPETAn
      VGQhl5cqkWQ/uexFa+1JaNWmUsqvhq26CCCmqb6O5KfyXBn5+y0OrxbnqIZiLEgt
      HoaeYUnSa2vOOSqrMOXCoRzgpOLfgu4UnKZpNMBpKYYi3rkDv3OwBxU66KsN60NL
      FBeGoyzLwRPXobgpsfbkyCjkIM15JsHJ
      -----END PRIVATE KEY-----      
    END
  end

  let(:js) do
    <<~END
      console.log('Javascript!');
    END
  end

  let(:signature) do
    # This signature was generated using the private key above
    # rubocop:disable Layout/LineLength
    'a18a64dcfc40977cfc61c5cce4285f5543cc1e4b819102c642be02b509329d8a17fc9f7cd29f3450d2f71efce1beeb1d1c5bde316c1cf6f08124a70d50701d1a3dc8aeb0fd5d78bec6b6d6efe2f7077233d1b40b59629121be1f45f1f239bbfe5d45770d30b7e050e42f46e9dea08bb1f5e9dc840a4d701898d718f760aece95d67ae720ab56e00e31d785fdd77ff7a01b1a8ae60184f523702e9b30db77d181490d68c25a0e177b80815bb93849be9b48aae1e5099ca8fed4ad304fd4a436ce35ee779dd4481f8062a45aabf1546db568d87ee99b1825ef25a734b574d8377c54293d82953e3334b76e83a3dc249aa9c7ba09bd1f397167c019ecad3d6a741263c13afc0140615be97725dce64189ab82c0a5b0988174d1df81167e0f062c735d6a3f059f5f8e277c3c0a9e7652b59edd9079399e5255ac1a06b6dbd7eadb5f610329e14eb32b30e4a0e30448e33b1d656573a7aaa6ff84576d5c3c0d49f14d501157afeaa6b7be43084b55befad30f7566601ec3f4a30c350ae64eb0df078c0750117498cb8d2cb2386df964048285065689d51cf74c2aff39d6c6316f20b4fe2cf7cc52002fc473e38aef3593c9a373b5667caad85c869d39ccea2354189890f8dccfcccc4b1671b648283bb21749a351506ac4b22053c0e660cdc8096556a319d9710a53e7448a41243f3905ecc44543eda48c69481574f504bd37f09dce'
    # rubocop:enable Layout/LineLength
  end

  let(:http_response_status) { 200 }

  let(:http_response_body) do
    if signature.nil?
      js
    else
      "#{js}//#{signature}"
    end
  end

  describe '#perform' do
    let(:instance) { described_class.new }

    subject(:perform) do
      instance.perform(
        session_id: threatmetrix_session_id,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).
        and_return(threatmetrix_org_id)
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_js_signing_cert).
        and_return(threatmetrix_signing_certificate)
      allow(IdentityConfig.store).to receive(:proofing_device_profiling_collecting_enabled).
        and_return(proofing_device_profiling_collecting_enabled)

      stub_request(:get, "https://h.online-metrix.net/fp/tags.js?org_id=#{threatmetrix_org_id}&session_id=#{threatmetrix_session_id}").
        to_return(
          status: http_response_status,
          body: http_response_body,
        )
    end

    context 'when collecting is disabled' do
      let(:proofing_device_profiling_collecting_enabled) { false }
      it 'does not run' do
        expect(instance.logger).not_to receive(:info)
        perform
      end
    end

    context 'when certificate is not configured' do
      let(:threatmetrix_signing_certificate) { nil }
      it 'does not run' do
        expect(instance.logger).not_to receive(:info)
        perform
      end
    end

    context 'when certificate is expired' do
      it 'raises an error'
    end

    context 'when org id is not configured' do
      let(:threatmetrix_org_id) { nil }
      it 'does not run' do
        expect(instance.logger).not_to receive(:info)
        perform
      end
    end

    context 'http request returns empty 204 response' do
      let(:http_response_status) { 204 }
      let(:http_response_body) { '' }

      it 'fails' do
        expect(instance.logger).to receive(:info) do |message|
          expect(JSON.parse(message, symbolize_names: true)).to include(
            name: 'ThreatMetrixJsVerification',
            valid: false,
            http_status: 204,
          )
        end
        perform
      end
    end

    context 'http request succeeds' do
      context 'signature not present' do
        let(:signature) { nil }

        it 'logs a failure including JS payload' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              valid: false,
              js: js,
            )
          end

          perform
        end
      end

      context 'signature not a hex number' do
        let(:signature) { 'not an actual hex number' }
        it 'logs a failure including JS payload' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              valid: false,
              signature: '',
              js: http_response_body,
            )
          end
          perform
        end
      end

      context 'signature present but invalid' do
        let(:signature) { 'bad' }

        it 'logs a failure including JS payload' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              valid: false,
              js: js,
            )
          end

          perform
        end
      end

      context 'signature present and correct' do
        it 'logs on success' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              session_id: threatmetrix_session_id,
              signature: signature,
              valid: true,
              http_status: 200,
              certificate_expiry: '2032-09-06T16:00:01.000Z',
            )
          end

          perform
        end
      end
    end
  end
end
