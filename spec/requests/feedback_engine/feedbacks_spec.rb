# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Feedback submission', type: :request do
  let(:png) do
    Rack::Test::UploadedFile.new(
      File.expand_path('../../fixtures/tiny.png', __dir__), 'image/png'
    )
  end
  let(:txt) do
    Rack::Test::UploadedFile.new(
      File.expand_path('../../fixtures/note.txt', __dir__), 'text/plain'
    )
  end

  describe 'POST /feedback/feedbacks' do
    it 'stores the feedback with request metadata' do
      post '/feedback/feedbacks',
           params: { feedback: { kind: 'bug', section: 'Billing', message: 'It broke',
                                 page_url: 'http://example.com/billing' } },
           headers: { 'User-Agent' => 'TestBrowser/1.0' }

      expect(response).to have_http_status(:created)

      feedback = FeedbackEngine::Feedback.last
      expect(feedback.kind).to eq('bug')
      expect(feedback.section).to eq('Billing')
      expect(feedback.message).to eq('It broke')
      expect(feedback.page_url).to eq('http://example.com/billing')
      expect(feedback.user_agent).to eq('TestBrowser/1.0')
      expect(feedback.status).to eq('open')
    end

    it 'attributes the author via the configured hooks' do
      user = Struct.new(:id, :email).new(42, 'user@example.com')
      FeedbackEngine.config.current_user = ->(_request) { user }

      post '/feedback/feedbacks', params: { feedback: { kind: 'other', message: 'Hello' } }

      feedback = FeedbackEngine::Feedback.last
      expect(feedback.author_id).to eq('42')
      expect(feedback.author_label).to eq('user@example.com')
    end

    it 'calls the on_submit hook' do
      submitted = []
      FeedbackEngine.config.on_submit = ->(feedback) { submitted << feedback }

      post '/feedback/feedbacks', params: { feedback: { kind: 'other', message: 'Hello' } }

      expect(submitted.map(&:message)).to eq(['Hello'])
    end

    it 'rejects a blank message' do
      post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: '' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors']).to be_present
      expect(FeedbackEngine::Feedback.count).to eq(0)
    end

    it 'rejects an unknown kind' do
      post '/feedback/feedbacks', params: { feedback: { kind: 'spam', message: 'Hi' } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'is forbidden when the gate says no' do
      FeedbackEngine.config.enabled = ->(_request) { false }

      post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: 'It broke' } }

      expect(response).to have_http_status(:forbidden)
      expect(FeedbackEngine::Feedback.count).to eq(0)
    end

    context 'with screenshots' do
      it 'attaches uploaded images' do
        post '/feedback/feedbacks',
             params: { feedback: { kind: 'bug', message: 'See attached', screenshots: [png] } }

        expect(response).to have_http_status(:created)
        expect(FeedbackEngine::Feedback.last.screenshots.count).to eq(1)
      end

      it 'rejects more screenshots than allowed' do
        FeedbackEngine.config.max_screenshots = 1

        post '/feedback/feedbacks',
             params: { feedback: { kind: 'bug', message: 'Two shots', screenshots: [png, png] } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(FeedbackEngine::Feedback.count).to eq(0)
      end

      it 'rejects oversized screenshots' do
        FeedbackEngine.config.max_screenshot_size = 10

        post '/feedback/feedbacks',
             params: { feedback: { kind: 'bug', message: 'Big shot', screenshots: [png] } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects non-image uploads' do
        post '/feedback/feedbacks',
             params: { feedback: { kind: 'bug', message: 'A file', screenshots: [txt] } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects uploads when screenshots are disabled' do
        FeedbackEngine.config.screenshots = false

        post '/feedback/feedbacks',
             params: { feedback: { kind: 'bug', message: 'Shot', screenshots: [png] } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'still accepts feedback without screenshots when disabled' do
        FeedbackEngine.config.screenshots = false

        post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: 'No shot' } }

        expect(response).to have_http_status(:created)
      end
    end
  end
end
