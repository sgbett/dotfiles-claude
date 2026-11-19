# frozen_string_literal: true

module CopilotCheck
  module Testing
    # A failed check's job as GitHub's jobs API gives it, read once the
    # check's annotations pass. GateCalls includes it.
    module JobAnswers
      # A job's steps' conclusions when only its check's own step failed.
      ONE_FAILED_STEP = %w[success success failure skipped success].freeze

      def job_call(job)
        ['gh', 'api', '--hostname', 'github.com', '-X', 'GET', "repos/#{GateCalls::HERE}/actions/jobs/#{job}"]
      end

      # A job answer whose steps conclude as +conclusions+ say, in order.
      def job_response(job, conclusions)
        steps = conclusions.map.with_index(1) do |conclusion, number|
          { 'name' => "Step #{number}", 'number' => number, 'status' => 'completed', 'conclusion' => conclusion }
        end
        { 'id' => job, 'status' => 'completed', 'conclusion' => 'failure', 'steps' => steps }
      end
    end
  end
end
