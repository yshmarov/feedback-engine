# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Widget tag', type: :request do
  it 'renders the config block and the nonced widget script' do
    get '/sample'

    expect(response.body).to include('data-feedback-engine-config')
    expect(response.body).to include('<script data-feedback-engine-widget nonce="testnonce">')
    expect(response.body).to include('"endpoint":"/feedback/feedbacks"')
  end

  it 'renders nothing when feedback is disabled for the request' do
    FeedbackEngine.config.enabled = ->(_request) { false }

    get '/sample'

    expect(response.body).not_to include('data-feedback-engine-config')
    expect(response.body).not_to include('data-feedback-engine-widget')
  end
end
