# typed: strict
# frozen_string_literal: true

require "tapioca/internal"
require "minitest/autorun"
require "minitest/spec"
require "minitest/hooks/default"
require "minitest/reporters"
require "rails/test_unit/line_filtering"
require "byebug"

require "tapioca/helpers/test/content"
require "tapioca/helpers/test/template"
require "tapioca/helpers/test/isolation"
require_relative "spec_reporter"
require_relative "dsl_spec_helper"
require_relative "spec_with_project"

Minitest::Reporters.use!(SpecReporter.new(color: true))

module Minitest
  class Test
    extend T::Sig
    extend Rails::LineFiltering
  end
end
