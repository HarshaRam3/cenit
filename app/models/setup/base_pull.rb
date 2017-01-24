module Setup
  class BasePull < Setup::Task
    include UploaderHelper
    include RailsAdmin::Models::Setup::BasePullAdmin

    abstract_class

    build_in_data_type

    mount_uploader :pull_request, AccountUploader
    mount_uploader :pulled_request, AccountUploader

    def pull_request_hash
      @pull_request_hash ||= hashify(pull_request)
    end

    def pulled_request_hash
      @pulled_request_hash ||= hashify(pulled_request)
    end

    def run(message)
      clear_hashes
      if pull_request_hash.present?
        pull_request_hash[:install] = message[:install].to_b if ask_for_install?
        pulled_request_hash = Cenit::Actions.pull(source_shared_collection, pull_request_hash)
        self.remove_pull_request = true
        {
          fixed_errors: :warning,
          errors: :error
        }.each do |key, type|
          (pulled_request_hash[key] || []).each do |msg|
            notify(message: msg, type: type)
          end
        end
        store pulled_request_hash.to_json, on: pulled_request
      else
        self.remove_pulled_request = true
        msg_pull_request = message.dup
        msg_pull_request[:updated_records_ids] = true
        pull_request_hash = Cenit::Actions.pull_request(source_shared_collection, msg_pull_request)
        review_warning = message[:skip_pull_review].to_b &&
          (pull_request_hash[:new_records].present? || pull_request_hash[:updated_records].present?)
        store pull_request_hash.to_json, on: pull_request
        if pull_request_hash[:missing_parameters].blank? && review_warning
          notify(message: 'Skipping pull review', type: :warning)
          run(message)
        else
          notify(message: 'Waiting for pull review', type: :notice)
          resume_manually
        end
      end
    end

    protected

    def clear_hashes
      @pull_request_hash = @pulled_request_hash = nil
    end

    def source_shared_collection
      fail NotImplementedError
    end

    def ask_for_install?
      false
    end

    def hashify(uploader)
      begin
        JSON.parse(uploader.read || '{}').with_indifferent_access
      rescue Exception => ex
        fail "Invalid JSON #{uploader.mounted_as}: #{ex.message}"
      end
    end
  end
end
