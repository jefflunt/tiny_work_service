Gem::Specification.new do |s|
  s.name        = "tiny_work_service"
  s.version     = "3.2.0"
  s.description = "uses the tiny_tcp_service gem to implement a network job queue"
  s.summary     = "uses the tiny_tcp_service gem to implement a network job queue"
  s.authors     = ["Jeff Lunt"]
  s.email       = "jefflunt@gmail.com"
  s.files       = ["lib/tiny_work_service.rb"]
  s.homepage    = "https://github.com/jefflunt/tiny_work_service"
  s.license     = "MIT"

  s.add_runtime_dependency 'tiny_tcp_service', [">= 1.4"]
  s.add_runtime_dependency 'tiny_eta', [">= 1.0"]
end
