# frozen_string_literal: true

RSpec.describe "I18n" do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    # lazy-load i18n-tasks to save 150ms spec boot time
    require "i18n/tasks"
  end

  let(:i18n) { I18n::Tasks::BaseTask.new }
  let(:missing_keys) { i18n.missing_keys }
  let(:unused_keys) { i18n.unused_keys }
  let(:inconsistent_interpolations) { i18n.inconsistent_interpolations }

  it "does not have missing keys" do
    pending "Enable when i18n-tasks is enabled across the project, otherwise this spec will report false positives"

    expect(missing_keys).to be_empty,
                            "Missing #{missing_keys.leaves.count} i18n keys, run `i18n-tasks missing' to show them"
  end

  it "does not have unused keys" do
    expect(unused_keys).to be_empty,
                           "#{unused_keys.leaves.count} unused i18n keys, run `i18n-tasks unused' to show them"
  end

  it "files are normalized" do
    non_normalized = i18n.non_normalized_paths
    error_message = "The following files need to be normalized:\n" \
                    "#{non_normalized.map { |path| "  #{path}" }.join("\n")}\n" \
                    "Please run `i18n-tasks normalize' to fix"
    expect(non_normalized).to be_empty, error_message
  end

  context "for all i18n files" do
    let(:root_dir) { Pathname.new(__FILE__).dirname.join("..") }
    let(:config_file) { root_dir.join("config/i18n-tasks-all-files.yml") }
    let(:i18n) { I18n::Tasks::BaseTask.new(config_file:) }

    it "does not have inconsistent interpolations" do
      config_file_relative_path = config_file.relative_path_from(Dir.pwd)
      error_message = "#{inconsistent_interpolations.leaves.count} i18n keys have inconsistent interpolations.\n" \
                      "Run 'i18n-tasks check-consistent-interpolations --config #{config_file_relative_path}' to show them"
      expect(inconsistent_interpolations).to be_empty, error_message
    end
  end
end
