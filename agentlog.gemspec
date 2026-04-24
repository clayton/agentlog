# frozen_string_literal: true

require_relative "lib/agentlog/version"

Gem::Specification.new do |spec|
  spec.name = "agentlog"
  spec.version = Agentlog::VERSION
  spec.authors = ["Clayton Lengel-Zigich"]
  spec.email = ["6334+clayton@users.noreply.github.com"]

  spec.summary = "Compact Rails request logs for coding agents in development and test."
  spec.description = [
    "Agentlog adds a second Rails logger that emits terse, token-efficient",
    "request summaries for coding agents while leaving development.log untouched."
  ].join(" ")
  spec.homepage = "https://github.com/clayton/agentlog"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = "https://github.com/clayton/agentlog"
  spec.metadata["changelog_uri"] = "https://github.com/clayton/agentlog/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |file|
      (file == gemspec) ||
        file.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |file| File.basename(file) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.1", "< 9"
  spec.add_dependency "railties", ">= 8.0", "< 8.2"
end
