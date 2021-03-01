# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Threema::Client do
  it 'has API_URL constant' do
    expect(described_class).to have_constant(:API_URL)
  end

  it 'responds to url' do
    expect(described_class).to respond_to(:url)
  end

  let(:instance) { build(:threema_client) }

  context '#not_found_ok' do
    it 'responds to not_found_ok' do
      expect(instance).to respond_to(:not_found_ok)
    end

    it 'allows 404 responses' do
      mock_error(404)
      expect(
        instance.not_found_ok do
          instance.get(described_class::API_URL)
        end
      ).to be nil
    end

    it 'tunnels other exeptions' do
      mock_error(400)
      expect do
        instance.not_found_ok do
          instance.get(described_class::API_URL)
        end
      end.to raise_error(RequestError)
    end
  end

  context 'HTTP Public Key Pinning' do
    before(:all) do
      WebMock.allow_net_connect!
    end

    after(:all) do
      WebMock.disable_net_connect!
    end

    # this is needed due to internet access restrictions
    # in the (travis) CI environment
    if !ENV['CI']
      it 'checks the HTTP Public Key Pinning' do
        expect { instance.get(described_class::API_URL) }.to raise_error(RequestError)
      end
    end

    it "throws OpenSSL::SSL::SSLError exception if HTTP Public Key Pinning doesn't match" do
      expect { instance.get('https://requestb.in/zpi5cuzp') }.to raise_error(OpenSSL::SSL::SSLError)
    end

    it 'throws no exception if HTTP Public Key Pinning is disabled' do
      instance = build(:threema_client, public_key_pinning: false)
      expect { instance.get('https://requestb.in/zpi5cuzp') }.to_not raise_error
    end
  end

  context 'error responds' do
    it 'throws Unauthorized exception on 401 responds' do
      mock_error(401)
      expect { instance.get(described_class::API_URL) }.to raise_error(Unauthorized)
    end

    it 'throws RemoteError exception on 500 responds' do
      mock_error(500)
      expect { instance.get(described_class::API_URL) }.to raise_error(RemoteError)
    end

    it 'throws RequestError exception on other failure responds' do
      mock_error(402)
      expect { instance.get(described_class::API_URL) }.to raise_error(RequestError, /Net::HTTPPaymentRequired/)
    end
  end
end
