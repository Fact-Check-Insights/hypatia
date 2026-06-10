# frozen_string_literal: true

require "test_helper"

class BirdsongTest < Minitest::Test
  def test_that_it_has_a_version_number
    assert_same ::Birdsong::VERSION.nil?, false
  end

  def test_that_errors_can_be_thrown
    assert_raises(Birdsong::Error) do
      raise Birdsong::Error
    end

    assert_raises(Birdsong::AuthorizationError) do
      raise Birdsong::AuthorizationError, "This is a test"
    end

    assert_raises(Birdsong::InvalidIdError) do
      raise Birdsong::InvalidIdError
    end
  end
end
