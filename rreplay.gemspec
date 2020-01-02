Gem::Specification.new do |spec|
  spec.name          = "rreplay"
  spec.version       = "0.2.1"
  spec.authors       = ["petitviolet"]
  spec.email         = ["violethero0820@gmail.com"]

  spec.summary       = %q{A rack middleware and replayer HTTP request/response}
  spec.description   = %q{A rack middleware to dump request and response, and replayer of recorded requests}
  spec.homepage      = "https://github.com/petitviolet/rreplay"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/petitviolet/rreplay"
  spec.metadata["changelog_uri"] = "https://github.com/petitviolet/rreplay"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec|test|example)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})

  spec.add_dependency "rack"
  spec.add_dependency "msgpack"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "json_expressions"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "timecop"
end
