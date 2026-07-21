# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackEngine::Feedback do
  it 'is valid with a message and a known kind' do
    feedback = described_class.new(kind: 'bug', message: 'It broke')
    expect(feedback).to be_valid
  end

  it 'requires a message' do
    feedback = described_class.new(kind: 'bug', message: '')
    expect(feedback).not_to be_valid
    expect(feedback.errors[:message]).to be_present
  end

  it 'rejects kinds outside the configured list' do
    feedback = described_class.new(kind: 'praise', message: 'Nice!')
    expect(feedback).not_to be_valid
  end

  it 'accepts kinds the host adds to the config' do
    FeedbackEngine.config.kinds = %w[bug praise]
    feedback = described_class.new(kind: 'praise', message: 'Nice!')
    expect(feedback).to be_valid
  end

  it 'defaults to open and validates status' do
    feedback = described_class.create!(kind: 'bug', message: 'It broke')
    expect(feedback).to be_open

    feedback.status = 'in_review'
    expect(feedback).to be_valid
    expect(feedback.in_review?).to be(true)

    feedback.status = 'wontfix'
    expect(feedback).not_to be_valid
  end

  it 'attaches screenshots' do
    feedback = described_class.create!(kind: 'bug', message: 'See attached')
    feedback.screenshots.attach(
      io: File.open(File.expand_path('../../fixtures/tiny.png', __dir__)),
      filename: 'tiny.png',
      content_type: 'image/png'
    )
    expect(feedback.screenshots?).to be(true)
  end
end
