# frozen_string_literal: true

require_relative "lib/jekyll-semtree/version"

Gem::Specification.new do |spec|
  spec.name          = "jekyll-semtree"
  spec.version       = Jekyll::SemTree::VERSION
  spec.authors       = ["manunamz"]
  spec.email         = ["manunamz@pm.me"]

  spec.summary       = "You thought there was something in here, didn't you? 😉"
  # spec.description   = "TODO: Write a longer description or delete this line."
  spec.homepage      = "https://github.com/manunamz/jekyll-semtree"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")
  spec.licenses      = ["MIT"]

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/manunamz/jekyll-semtree"
  spec.metadata["changelog_uri"] = "https://github.com/manunamz/jekyll-semtree/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir["lib/**/*"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", "~> 4.2.0"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
