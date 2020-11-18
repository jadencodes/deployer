defmodule SampleWebappTest do
  use ExUnit.Case
  doctest SampleWebapp

  test "greets the world" do
    assert SampleWebapp.hello() == :world
  end
end
