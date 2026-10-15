# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoogleBooksSearch do
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
    [400, 401, 403, 429, 500].each do |status|
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

  def provider_response(status, payload)
    instance_double(HTTParty::Response, code: status, parsed_response: payload)
  end
end
