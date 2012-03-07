# Copyright 2011 ThoughtWorks, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You may
# obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
# 
require 'rake/clean'
require 'rakejava'
require 'rake_helper'

require 'spec/rake/spectask'
def specs(definition) Spec::Rake::SpecTask.new(definition) { |t| yield t } end

task :default => :test

task :full => [:clean, :test]

desc 'Run Mira once using local config file.'
task :run do
  sh "./mingle-jira-connector.sh"
end

desc 'Build NailGun binary; must be run once on each development box.'
task :build_nailgun do
  cd 'tools/jruby-1.5.6/tool/nailgun' do
    sh './configure && make'
  end
end

task :test => [:spec, :junit]

task :spec => [:fast, :slow, :scenarios]

task :fake_jira => [:listener_jar, :fake_jira_jar]

specs :fast do |t|
  t.spec_files = FileList['spec/**/*_spec.rb'].
    delete_if { |i| i.include?("slow") || i.include?("scenario")}
end

specs :slow do |t|
  t.spec_files = FileList['spec/slow/*_spec.rb']
end

specs :scenarios => [:fake_jira]  do |t|
  t.spec_files = 'spec/scenario/scenario_spec.rb'
end

def do_coverage t, files, *args
  t.spec_files = files
  t.rcov = true
  t.rcov_opts = [ '--exclude', 'jruby,eval', '--exclude', 'yaml', '--exclude', '\<script\>',
                 '--exclude', '\(__FORWARDABLE__\)', '--text-summary'].concat args
end

specs :lib_coverage => [:fake_jira] do |t|
  do_coverage t, FileList['spec/**/*_spec.rb'], '--failure-threshold', '--exclude', 'spec'
end

specs :scenarios_coverage => [:fake_jira] do |t|
  do_coverage t, FileList['spec/scenario/scenario_spec.rb'], '--exclude', 'spec'
end

specs :full_coverage => [:fake_jira] do |t|
  do_coverage t, FileList['spec/**/*_spec.rb']
end

task :listener_jar => BUILD[:listener_jar]
jar BUILD[:listener_jar] => [:compile_src, 'tmp/build'] do |t|
  cp_r 'java/src/resources', 'tmp/build'
  add_version_number 'tmp/build/resources'
  t.files << JarFiles['tmp/build/classes/src', '**/*.class']
  t.files << JarFiles['tmp/build/resources', '**/*']
  t.manifest = {"Implementation-Version" => macro_version_short}
end

javac :compile_src => 'tmp/build/classes/src' do |t|
  t.src << Sources['java/src', '**/*.java']
  t.classpath << Dir['java/lib/*.jar']
  t.dest = 'tmp/build/classes/src'
end

javac :compile_tests => ['tmp/build/classes/tests', :compile_src] do |t|
  t.src << Sources['java/test', '**/*.java']
  t.classpath << Dir['java/lib/*.jar']
  t.classpath << 'tmp/build/classes/src'
  t.dest = 'tmp/build/classes/tests'
end

javac :compile_fake_jira => ['tmp/build/classes/fake-jira'] do |t|
  t.src << Sources['java/fake-jira', '**/*.java']
  t.dest = 'tmp/build/classes/fake-jira'
end

task :junit => [:compile_src, :compile_tests, :compile_fake_jira] do
  jars = %w{junit-4.8.2 mockito-all-1.8.5 make-it-easy-3.1.0}.
    map { |j| "java/lib/#{j}.jar"}.join(':')
  junit_result = `java -classpath tmp/build/classes/fake-jira:tmp/build/classes/src:tmp/build/classes/tests:#{jars} org.junit.runner.JUnitCore com.thoughtworks.mingleconnector.AllTests | grep -v 'at org\.junit\.'`
  puts junit_result
  junit_result.include?("FAILURES!!!") and raise "Tests failed"
end

task :fake_jira_jar => 'tmp/build/fake-jira.jar'
jar 'tmp/build/fake-jira.jar' => [:compile_fake_jira, 'tmp/build'] do |t|
  t.files << JarFiles['tmp/build/classes/fake-jira', '**/*.class']
end

task :java_watch do
  sh <<-SH
    while inotifywait --recursive --exclude ".*\.#.*" --quiet \
                      --event modify --event move --event create --event delete \
                      java Rakefile
    do
      rake junit
    done
  SH
end

directory 'tmp/build/classes/src'
directory 'tmp/build/classes/tests'
directory 'tmp/build/classes/fake-jira'

def build_dir dir
  directory dir
  CLEAN.include dir
end
build_dir 'tmp'

def clean path
  rm_r path if File.exists? path
  mkdir_p path
end
