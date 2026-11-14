# frozen_string_literal: true

# What any skill's examination of its scripts' checkout shares; /do's
# scripts_checkout_spec.rb covers what it reads and digests, through /do's
# Do::ScriptsCheckout.
RSpec.describe SkillSupport::ScriptsCheckout do
  let(:top) { sandbox.path('scripts') }
  # Words the ask as a skill's Reasons does.
  let(:reasons) do
    Module.new do
      def self.ask(reason, **details)
        { reason: reason, message: "#{reason}, in the skill's words", **details }
      end
    end
  end

  def git(*arguments)
    output, status = Open3.capture2e('git', '-C', top, *arguments)
    raise "git #{arguments.join(' ')} failed: #{output}" unless status.success?
  end

  # A checkout holding two skills and skills/_support, committed, with HEAD
  # the default branch origin names.
  def reviewed_checkout
    { 'skills/copilot-check/lib/setup.rb' => "# setup\n", 'skills/do/lib/check.rb' => "# check\n",
      'skills/_support/lib/support.rb' => "# support\n" }.each do |path, text|
      FileUtils.mkdir_p(File.dirname(File.join(top, path)))
      File.write(File.join(top, path), text)
    end
    git('init', '--quiet', '--initial-branch=master')
    [%w[add .], %w[commit --quiet -m Scripts], %w[update-ref refs/remotes/origin/master HEAD],
     %w[symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master]].each { |arguments| git(*arguments) }
  end

  def examine(accepted: nil)
    described_class.new(SkillSupport::CommandRunner.new, skill_directory: File.join(top, 'skills', 'copilot-check'),
                                                         reasons: reasons)
                   .examine(accepted: accepted)
  end

  it "examines the skill it is given, not another, and asks in that skill's words until a yes names the digest" do
    reviewed_checkout
    File.write(File.join(top, 'skills', 'do', 'lib', 'check.rb'), "# changed\n")
    expect(examine.ask).to be_nil

    File.write(File.join(top, 'skills', 'copilot-check', 'lib', 'setup.rb'), "# changed\n")
    inspection = examine

    expect([inspection.changes.map(&:to_s), inspection.ask])
      .to eq([[' M skills/copilot-check/lib/setup.rb'],
              { reason: :scripts_unreviewed, message: "scripts_unreviewed, in the skill's words",
                accept_with: ['--accept-scripts', inspection.token] }])
    expect(examine(accepted: inspection.token).ask).to be_nil
  end
end
