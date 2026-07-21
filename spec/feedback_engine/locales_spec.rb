# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

LOCALE_FILES = Dir[File.expand_path('../../config/locales/*.yml', __dir__)]

# The widget keys every locale must ship. English additionally carries the
# dashboard keys (admin-facing; other locales fall back to English there).
WIDGET_KEYS = %w[
  button title kind kinds.bug kinds.feature kinds.other section section_any
  message message_placeholder screenshots screenshots_hint submit cancel
  close thanks error_blank error_save error_too_many error_too_large
].freeze

PLACEHOLDERS = {
  'screenshots_hint' => ['%{count}', '%{size}'],
  'error_too_many' => ['%{count}'],
  'error_too_large' => ['%{size}']
}.freeze

RSpec.describe 'Bundled locales' do

  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full = [prefix, key].compact.join('.')
      value.is_a?(Hash) ? flatten_keys(value, full) : [full]
    end
  end

  it 'ships at least the six original languages' do
    locales = LOCALE_FILES.map { |f| File.basename(f)[/feedback_engine\.(.+)\.yml/, 1] }
    expect(locales).to include('en', 'es', 'fr', 'de', 'pt', 'uk')
  end

  LOCALE_FILES.each do |file|
    locale = File.basename(file)[/feedback_engine\.(.+)\.yml/, 1]

    describe "#{locale} (#{File.basename(file)})" do
      let(:data) do
        yaml = YAML.safe_load_file(file)
        expect(yaml.keys).to eq([locale])
        yaml.fetch(locale).fetch('feedback_engine')
      end

      it 'contains every widget key' do
        expect(flatten_keys(data)).to include(*WIDGET_KEYS)
      end

      it 'keeps the interpolation placeholders intact' do
        PLACEHOLDERS.each do |key, tokens|
          tokens.each do |token|
            expect(data.fetch(key)).to include(token), "#{locale}.#{key} is missing #{token}"
          end
        end
      end

      it 'has no blank values' do
        values = data.values.flat_map { |v| v.is_a?(Hash) ? v.values : [v] }
        expect(values).to all(be_a(String) & satisfy('be non-blank') { |v| !v.strip.empty? })
      end
    end
  end
end
