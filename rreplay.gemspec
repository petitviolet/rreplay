Gem::Specification.new do |spec|
  spec.name          = "rreplay"
  spec.version       = "0.1.0"
  spec.authors       = ["petitviolet"]
  spec.email         = ["violethero0820@gmail.com"]

  spec.summary       = %q{A rack middleware to dump request and response to replay request}
  spec.description   = %q{A rack middleware to dump request and response to replay request}
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
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "timecop"
end
