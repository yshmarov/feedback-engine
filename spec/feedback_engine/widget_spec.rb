# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackEngine::Widget do
  def parsed_config(html)
    json = html[%r{<script type="application/json" data-feedback-engine-config>(.*?)</script>}m, 1]
    JSON.parse(json.gsub('<\/', '</'))
  end

  describe '.snippet' do
    it 'ships the endpoint, kinds, sections, and limits as JSON data' do
      FeedbackEngine.config.sections = %w[Dashboard Billing]

      html = described_class.snippet(endpoint: '/feedback/feedbacks', locale: :en)
      config = parsed_config(html)

      expect(config['endpoint']).to eq('/feedback/feedbacks')
      expect(config['kinds']).to eq([
                                      { 'value' => 'bug', 'label' => 'Bug report' },
                                      { 'value' => 'feature', 'label' => 'Feature request' },
                                      { 'value' => 'other', 'label' => 'Other' }
                                    ])
      expect(config['sections']).to eq(%w[Dashboard Billing])
      expect(config['screenshots']).to eq('enabled' => true, 'max' => 3, 'maxSize' => 5 * 1024 * 1024)
      expect(config['rtl']).to be(false)
    end

    it 'stamps the nonce on the widget script only' do
      html = described_class.snippet(endpoint: '/x', locale: :en, nonce: 'abc123')

      expect(html).to include('<script data-feedback-engine-widget nonce="abc123">')
      expect(html).to include('<script type="application/json" data-feedback-engine-config>')
      expect(html).not_to include('data-feedback-engine-config nonce')
    end

    it 'escapes </ so config values cannot close the script block' do
      FeedbackEngine.config.button_label = '</script><script>alert(1)</script>'

      html = described_class.snippet(endpoint: '/x', locale: :en)
      json = html[%r{<script type="application/json" data-feedback-engine-config>(.*?)</script>}m, 1]

      expect(json).not_to include('</script>')
      expect(parsed_config(html)['buttonLabel']).to eq('</script><script>alert(1)</script>')
    end

    it 'flags RTL locales' do
      html = described_class.snippet(endpoint: '/x', locale: :'ar-EG')
      expect(parsed_config(html)['rtl']).to be(true)
    end

    it 'localizes the labels' do
      I18n.with_locale(:fr) do
        html = described_class.snippet(endpoint: '/x', locale: :fr)
        expect(parsed_config(html)['labels']['title']).to eq('Envoyer un commentaire')
      end
    end
  end
end
