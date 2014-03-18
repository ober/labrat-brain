guard 'rspec', :version => 2 do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})      { "spec/brain_spec.rb" }
  watch(%r{^lib/cfn/(.+)\.rb$})  { "spec/brain_spec.rb" }
  watch('spec/spec_helper.rb')   { "spec/brain_spec.rb" }
end

guard 'bundler' do
  watch('Gemfile')
  watch(/^.+\.gemspec/)
end
