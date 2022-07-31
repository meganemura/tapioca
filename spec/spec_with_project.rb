# typed: strict
# frozen_string_literal: true

require_relative "helpers/mock_project"

module Tapioca
  class SpecWithProject < Minitest::HooksSpec
    extend T::Sig

    TEST_TMP_PATH = "/tmp/tapioca/tests"

    # Spec lifecycle

    # TODO: Replace by `before(:all)` once Sorbet understands it
    sig { params(args: T.untyped).void }
    def initialize(*args)
      super(*T.unsafe(args))
      @project = T.let(mock_project, MockProject)
    end

    # TODO: Remove this `before(:all)` once Sorbet understands `after(:all)` or instance variables access after a bind
    sig { returns(MockProject) }
    attr_reader :project

    after(:all) do
      project.destroy
    end

    # Spec helpers

    # Create a new mock project for this spec
    #
    # Example:
    # ~~~
    # project = mock_project do
    #   write("lib/foo.rb")
    # end
    #
    # assert(@project.file?("lib/foo.rb"))
    # ~~~
    sig do
      params(
        sorbet_dependency: T::Boolean,
        block: T.nilable(T.proc.params(gem: MockProject).bind(MockProject).void)
      ).returns(MockProject)
    end
    def mock_project(sorbet_dependency: true, &block)
      project = MockProject.new("#{TEST_TMP_PATH}/#{spec_name}/project")
      project.gemfile(project.tapioca_gemfile)
      # Pin Sorbet static and runtime version to the current one in this project
      project.require_real_gem(
        "sorbet-static-and-runtime",
        ::Gem::Specification.find_by_name("sorbet-static-and-runtime").version.to_s
      ) if sorbet_dependency
      project.instance_exec(project, &block) if block
      project
    end

    # Create a new mock gem
    #
    #
    # Example:
    # ~~~
    # gem = mock_gem("foo", "1.0.0") do
    #   write("lib/foo.rb")
    # end
    #
    # assert(@gem.file?("lib/foo.rb"))
    # ~~~
    sig do
      params(
        name: String,
        version: String,
        dependencies: T::Array[String],
        block: T.nilable(T.proc.params(gem: MockGem).bind(MockGem).void)
      ).returns(MockGem)
    end
    def mock_gem(name, version, dependencies: [], &block)
      gem = MockGem.new("#{TEST_TMP_PATH}/#{spec_name}/gems/#{name}", name, version, dependencies)
      gem.gemspec(gem.default_gemspec_contents)
      gem.instance_exec(gem, &block) if block
      gem
    end

    # Spec assertions

    # Assert that the contents of `path` inside `@project` is equals to `expected`
    sig { params(path: String, expected: String).void }
    def assert_project_file_equal(path, expected)
      assert_equal(expected, @project.read(path))
    end

    # Assert that `path` exists inside `@project`
    sig { params(path: String).void }
    def assert_project_file_exist(path)
      assert(@project.file?(path))
    end

    # Refute that `path` exists inside `@project`
    sig { params(path: String).void }
    def refute_project_file_exist(path)
      refute(@project.file?(path))
    end

    sig { params(strictness: String, file: String).void }
    def assert_file_strictness(strictness, file)
      assert_equal(strictness, Spoom::Sorbet::Sigils.file_strictness(@project.absolute_path(file)))
    end

    sig { params(result: MockProject::ExecResult).void }
    def assert_empty_stdout(result)
      assert_empty(result.out)
    end

    sig { params(result: MockProject::ExecResult).void }
    def assert_empty_stderr(result)
      assert_empty(result.err)
    end

    sig { params(result: MockProject::ExecResult).void }
    def assert_success_status(result)
      assert(result.status)
    end

    sig { params(result: MockProject::ExecResult).void }
    def refute_success_status(result)
      refute(result.status)
    end

    private

    sig { returns(String) }
    def spec_name
      spec_class = T.unsafe(self).class
      spec_class = spec_class.superclass while spec_class.superclass != SpecWithProject
      name = spec_class.name&.split("::")&.last
      name.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
      name.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      name.downcase!
      name
    end
  end
end
