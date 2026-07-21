# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackEngine do
  let(:request) { instance_double(ActionDispatch::Request) }

  it 'has a version number' do
    expect(FeedbackEngine::VERSION).not_to be_nil
  end

  describe '.enabled?' do
    it 'defaults to true for everyone' do
      expect(described_class.enabled?(request)).to be(true)
    end

    it 'respects the configured gate' do
      described_class.config.enabled = ->(_request) { false }
      expect(described_class.enabled?(request)).to be(false)
    end
  end

  describe '.admin?' do
    it 'defaults to development only (so: denied in test)' do
      expect(described_class.admin?(request)).to be(false)
    end

    it 'respects the configured gate' do
      described_class.config.authorize_admin = ->(_request) { true }
      expect(described_class.admin?(request)).to be(true)
    end
  end

  describe FeedbackEngine::Configuration do
    it 'builds the submission endpoint from the mount path' do
      config = described_class.new
      expect(config.feedbacks_endpoint).to eq('/feedback/feedbacks')

      config.mount_path = '/support/'
      expect(config.feedbacks_endpoint).to eq('/support/feedbacks')
    end

    it 'enables screenshots when Active Storage is available' do
      expect(described_class.new.screenshots_enabled?).to be(true)
    end

    it 'disables screenshots when switched off' do
      config = described_class.new
      config.screenshots = false
      expect(config.screenshots_enabled?).to be(false)
    end
  end
end
