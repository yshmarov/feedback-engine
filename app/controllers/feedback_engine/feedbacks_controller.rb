# frozen_string_literal: true

module FeedbackEngine
  class FeedbacksController < ApplicationController
    PER_PAGE = 50

    layout 'feedback_engine/application', except: :create

    # The widget posts here; everything else is the triage dashboard.
    before_action :require_enabled, only: :create
    before_action :require_admin, except: :create
    before_action :set_feedback, only: %i[show update destroy]

    def index
      @status = Feedback::STATUSES.include?(params[:status]) ? params[:status] : 'open'
      @kind = FeedbackEngine.config.kinds.map(&:to_s).include?(params[:kind]) ? params[:kind] : nil
      @counts = Feedback.group(:status).count

      scope = Feedback.where(status: @status)
      scope = scope.where(kind: @kind) if @kind
      @page = [params[:page].to_i, 1].max
      @feedbacks = scope.newest_first.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = @feedbacks.size > PER_PAGE
      @feedbacks = @feedbacks.first(PER_PAGE)
    end

    def show; end

    def create
      feedback = Feedback.new(feedback_params)
      feedback.user_agent = request.user_agent
      attribute_author(feedback)

      error = attach_screenshots(feedback)
      return render json: { errors: [error] }, status: :unprocessable_entity if error

      if feedback.save
        FeedbackEngine.config.on_submit.call(feedback)
        head :created
      else
        render json: { errors: feedback.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @feedback.update!(params.require(:feedback).permit(:status))
      redirect_back fallback_location: feedback_path(@feedback), status: :see_other
    end

    def destroy
      @feedback.destroy!
      redirect_to root_path, status: :see_other
    end

    private

    def require_enabled
      head :forbidden unless FeedbackEngine.enabled?(request)
    end

    # Server-side gate for the dashboard. Default: development only.
    def require_admin
      return if FeedbackEngine.admin?(request)

      render plain: 'Forbidden. Set FeedbackEngine.config.authorize_admin to grant access.',
             status: :forbidden
    end

    def set_feedback
      @feedback = Feedback.find(params[:id])
    end

    def feedback_params
      params.require(:feedback).permit(:kind, :section, :message, :page_url)
    end

    def attribute_author(feedback)
      author = current_author
      return unless author

      feedback.author_id = author.id.to_s if author.respond_to?(:id)
      feedback.author_label = FeedbackEngine.config.author_label.call(author)
    end

    # Validates and attaches uploads. Returns an error message, or nil when
    # everything (including "no screenshots at all") is fine.
    def attach_screenshots(feedback)
      files = Array(params.dig(:feedback, :screenshots)).reject(&:blank?)
      return nil if files.empty?
      return t_error(:error_save) unless FeedbackEngine.config.screenshots_enabled?
      return t_error(:error_too_many, count: FeedbackEngine.config.max_screenshots) if too_many?(files)
      return t_error(:error_too_large, size: max_size_mb) if files.any? { |f| f.size > max_size }
      return t_error(:error_save) unless files.all? { |f| f.content_type.to_s.start_with?('image/') }

      feedback.screenshots.attach(files)
      nil
    end

    def too_many?(files)
      files.size > FeedbackEngine.config.max_screenshots
    end

    def max_size
      FeedbackEngine.config.max_screenshot_size
    end

    def max_size_mb
      max_size / (1024 * 1024)
    end

    def t_error(key, **args)
      defaults = {
        error_save: 'Could not send feedback. Please try again.',
        error_too_many: 'Too many screenshots (max %{count}).',
        error_too_large: 'A screenshot is too large (max %{size} MB).'
      }
      I18n.t(key, scope: :feedback_engine, default: defaults[key], **args)
    end
  end
end
