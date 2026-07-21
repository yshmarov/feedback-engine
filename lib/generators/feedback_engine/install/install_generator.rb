# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module FeedbackEngine
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Installs feedback_engine: config initializer, migration, and engine mount.'

      def create_initializer
        copy_file 'initializer.rb', 'config/initializers/feedback_engine.rb'
      end

      def create_feedbacks_migration
        migration_template 'create_feedback_engine_feedbacks.rb.tt',
                           'db/migrate/create_feedback_engine_feedbacks.rb'
      end

      def mount_engine
        route %(mount FeedbackEngine::Engine => "/feedback")
      end

      def post_install
        say "\nfeedback_engine installed. Run `rails db:migrate`, then add", :green
        say '`<%= feedback_engine_tag %>` before </body> in your layout.'
        say "Browse submissions at /feedback (development only until you set config.authorize_admin).\n"
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
