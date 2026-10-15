# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoogleBooksSearch do
  include ActiveSupport::Testing::TimeHelpers

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  it 'reports a provider failure when the caller needs a distinct error state' do
    allow(GoogleBooks).to receive(:get).and_raise(Timeout::Error, 'Request timed out')
    expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable)
  end

  it 'keeps the existing empty-array fallback for other callers' do
    allow(GoogleBooks).to receive(:get).and_raise(Timeout::Error, 'Request timed out')
    expect(described_class.call('Dune')).to eq([])
  end

  it 'does not cache failures, so retry can succeed' do
    allow(GoogleBooks).to receive(:get).and_raise(Timeout::Error)
    expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable)
    payload = { 'totalItems' => 1, 'items' => [{ 'volumeInfo' => { 'title' => 'Dune' } }] }
    allow(GoogleBooks).to receive(:get).and_return(provider_response(200, payload))
    expect(described_class.call('Dune', raise_on_error: true).map(&:title)).to eq(['Dune'])
  end

  it 'reports HTTP failures instead of caching them as no matches' do
    [400, 401, 403, 500].each do |status|
      allow(GoogleBooks).to receive(:get).and_return(provider_response(status, { 'error' => { 'code' => status } }))
      expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable)
    end
  end

  it 'rejects a malformed successful response' do
    allow(GoogleBooks).to receive(:get).and_return(provider_response(200, '<html>Error</html>'))
    expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable)
  end

  it 'caches a valid empty search and bounds the request time' do
    request = a_string_including('q=intitle%3Adune', 'maxResults=10')
    response = provider_response(200, { 'totalItems' => 0 })
    expect(GoogleBooks).to receive(:get).with(request, timeout: 10).once.and_return(response)
    2.times { expect(described_class.call('intitle:Dune', raise_on_error: true)).to eq([]) }
  end

  it 'honors a rate-limit delay across queries without calling the provider again' do
    travel_to(Time.current.change(usec: 0)) do
      allow(GoogleBooks).to receive(:get).and_return(provider_response(429, {}, { 'retry-after' => '12' }))
      expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable) { |e|
        expect(e.reason).to eq(:rate_limited)
        expect(e.retry_after).to eq(12)
      }
      expect { described_class.call('Hobbit', raise_on_error: true) }.to raise_error(described_class::Unavailable)
      expect(GoogleBooks).to have_received(:get).once
      travel 13.seconds
      allow(GoogleBooks).to receive(:get).and_return(provider_response(200, { 'totalItems' => 0 }))
      expect(described_class.call('Dune', raise_on_error: true)).to eq([])
    end
  end

  it 'accepts a date Retry-After header and safely defaults an invalid one' do
    travel_to(Time.current.change(usec: 0)) do
      [(Time.current + 20.seconds).httpdate, 'invalid'].zip([20, 30]).each do |header, delay|
        Rails.cache.clear
        allow(GoogleBooks).to receive(:get).and_return(provider_response(429, {}, { 'retry-after' => header }))
        expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable) { |e|
          expect(e.retry_after).to eq(delay)
        }
      end
    end
  end

  it 'keeps cached books available during a provider cooldown' do
    allow(GoogleBooks).to receive(:get).and_return(provider_response(200, { 'totalItems' => 0 }))
    described_class.call('Dune', raise_on_error: true)
    allow(GoogleBooks).to receive(:get).and_return(provider_response(429, {}))
    expect { described_class.call('Hobbit', raise_on_error: true) }.to raise_error(described_class::Unavailable)
    expect(described_class.call('Dune', raise_on_error: true)).to eq([])
    expect(GoogleBooks).to have_received(:get).twice
  end

  it 'searches successfully when cache reads or writes fail' do
    allow(Rails.cache).to receive(:read).and_raise('Cache disconnected')
    allow(Rails.cache).to receive(:write).and_raise('Cache disconnected')
    allow(GoogleBooks).to receive(:get).and_return(provider_response(200, { 'totalItems' => 0 }))
    expect(described_class.call('Dune', raise_on_error: true)).to eq([])
    expect(GoogleBooks).to have_received(:get).once
  end

  it 'keeps usable volumes when another item has broken metadata' do
    payload = { 'totalItems' => 3, 'items' => [nil, { 'volumeInfo' => nil }, { 'volumeInfo' => { 'title' => 'Dune' } }] }
    allow(GoogleBooks).to receive(:get).and_return(provider_response(200, payload))
    expect(described_class.call('Dune', raise_on_error: true).map(&:title)).to eq(['Dune'])
  end

  it 'treats error payloads and wholly broken volumes as failures rather than no matches' do
    [{ 'totalItems' => 0, 'error' => {} }, { 'totalItems' => 1, 'items' => [nil] }].each do |payload|
      allow(GoogleBooks).to receive(:get).and_return(provider_response(200, payload))
      expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable)
    end
  end

  it 'classifies timeouts without logging raw request details' do
    allow(GoogleBooks).to receive(:get).and_raise(Timeout::Error, 'key=secret&query=private')
    expect(Rails.logger).to receive(:warn).with('[GoogleBooksSearch] failed: Timeout::Error (timeout)')
    expect { described_class.call('Dune', raise_on_error: true) }.to raise_error(described_class::Unavailable) { |e|
      expect(e.reason).to eq(:timeout)
      expect(e.message).to eq('Google Books took too long to respond.')
    }
  end

  def provider_response(status, payload, headers = {})
    instance_double(HTTParty::Response, code: status, parsed_response: payload, headers: headers)
  end
end
