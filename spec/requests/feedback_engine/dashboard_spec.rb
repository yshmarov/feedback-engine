# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Feedback dashboard', type: :request do
  def create_feedback(**attrs)
    FeedbackEngine::Feedback.create!({ kind: 'bug', message: 'It broke' }.merge(attrs))
  end

  def create_feedback_with_screenshot(**attrs)
    create_feedback(**attrs).tap do |feedback|
      feedback.screenshots.attach(
        io: File.open(File.expand_path('../../fixtures/tiny.png', __dir__)),
        filename: 'tiny.png',
        content_type: 'image/png'
      )
    end
  end

  context 'when not authorized (the default outside development)' do
    it 'forbids the index' do
      get '/feedback'
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids updates' do
      feedback = create_feedback
      patch "/feedback/feedbacks/#{feedback.id}", params: { feedback: { status: 'resolved' } }
      expect(response).to have_http_status(:forbidden)
      expect(feedback.reload.status).to eq('open')
    end

    it 'forbids screenshots' do
      feedback = create_feedback_with_screenshot
      get "/feedback/feedbacks/#{feedback.id}/screenshots/#{feedback.screenshots.first.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authorized' do
    before do
      FeedbackEngine.config.authorize_admin = ->(_request) { true }
    end

    it 'lists open feedback with status counts' do
      create_feedback(message: 'Open bug')
      create_feedback(message: 'Solved one', status: 'resolved')

      get '/feedback'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Open bug')
      expect(response.body).not_to include('Solved one')
    end

    it 'filters by status and kind' do
      create_feedback(message: 'A bug in review', status: 'in_review')
      create_feedback(message: 'A feature idea', kind: 'feature', status: 'in_review')

      get '/feedback', params: { status: 'in_review', kind: 'feature' }

      expect(response.body).to include('A feature idea')
      expect(response.body).not_to include('A bug in review')
    end

    it 'shows one feedback with its details' do
      feedback = create_feedback(section: 'Billing', page_url: 'http://example.com/x',
                                 author_label: 'user@example.com')

      get "/feedback/feedbacks/#{feedback.id}"

      expect(response.body).to include('It broke')
      expect(response.body).to include('Billing')
      expect(response.body).to include('user@example.com')
    end

    it 'renders screenshots via the gated engine route, not blob URLs' do
      feedback = create_feedback_with_screenshot
      screenshot_path = "/feedback/feedbacks/#{feedback.id}/screenshots/#{feedback.screenshots.first.id}"

      get "/feedback/feedbacks/#{feedback.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(src="#{screenshot_path}"))
      expect(response.body).not_to include('/rails/active_storage/')
    end

    it 'streams a screenshot to an admin' do
      feedback = create_feedback_with_screenshot

      get "/feedback/feedbacks/#{feedback.id}/screenshots/#{feedback.screenshots.first.id}"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('image/png')
      expect(response.headers['Content-Disposition']).to include('inline')
      expect(response.body.bytesize).to eq(feedback.screenshots.first.byte_size)
    end

    it '404s for a screenshot of another feedback' do
      feedback = create_feedback_with_screenshot
      other = create_feedback

      get "/feedback/feedbacks/#{other.id}/screenshots/#{feedback.screenshots.first.id}"

      expect(response).to have_http_status(:not_found)
    end

    it 'updates the status' do
      feedback = create_feedback

      patch "/feedback/feedbacks/#{feedback.id}", params: { feedback: { status: 'resolved' } }

      expect(response).to have_http_status(:see_other)
      expect(feedback.reload.status).to eq('resolved')
    end

    it 'deletes feedback' do
      feedback = create_feedback

      delete "/feedback/feedbacks/#{feedback.id}"

      expect(response).to have_http_status(:see_other)
      expect(FeedbackEngine::Feedback.exists?(feedback.id)).to be(false)
    end
  end
end
