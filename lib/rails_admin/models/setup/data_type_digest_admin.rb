module RailsAdmin
  module Models
    module Setup
      module DataTypeDigestAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            visible false
            object_label_method { :to_s }
            configure :attempts_succeded, :text do
              label 'Attempts/Succedded'
            end

            configure :data_type, :record

            edit do
              field :description
              field :auto_retry
            end

            list do
              field :data_type
              field :description
              field :scheduler
              field :attempts_succeded
              field :retries
              field :progress
              field :status
              field :updated_at
            end

            show do
              field :data_type
              field :payload
              field :options, :json
              field :description
              field :scheduler
              field :attempts_succeded
              field :retries
              field :progress
              field :status
              field :updated_at
            end

            fields :data_type, :description, :scheduler, :attempts_succeded, :retries, :progress, :status, :executions, :notifications, :updated_at
          end
        end
      end
    end
  end
end
