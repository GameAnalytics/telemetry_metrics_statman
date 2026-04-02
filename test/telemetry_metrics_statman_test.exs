defmodule TelemetryMetricsStatmanTest do
  use ExUnit.Case
  doctest TelemetryMetricsStatman
  import Mock

  test "test counter" do
    with_mock :statman, [:passthrough], [] do
      # Map Telemetry event [:bar, :baz] to Statman counter "foo.bar",
      # and [:foo, :baz] to "bar.foo".
      {:ok, pid} = TelemetryMetricsStatman.start_link(metrics: [
            Telemetry.Metrics.counter("foo.bar", event_name: [:bar, :baz]),
            Telemetry.Metrics.counter("bar.foo", event_name: [:foo, :baz], keep: & Map.has_key?(&1, :keep_it))])
      :telemetry.execute([:bar, :baz], %{})
      # Assert that the Statman counter was actually incremented
      assert_called_exactly(:statman.incr({:foo, :bar}, 1), 1)

      # Two out of three calls are kept, according to the "keep" function
      :telemetry.execute([:foo, :baz], %{}, %{keep_it: 1})
      :telemetry.execute([:foo, :baz], %{}, %{keep_it: 1})
      :telemetry.execute([:foo, :baz], %{}, %{})
      assert_called_exactly(:statman.incr({:bar, :foo}, 1), 2)

      Process.unlink(pid)
      Process.exit(pid, :kill)
    end
  end
end
