defmodule TelemetryMetricsStatmanTest do
  use ExUnit.Case
  doctest TelemetryMetricsStatman
  import Mock

  test "test counter" do
    with_mock :statman, [:passthrough], [] do
      # Map Telemetry event [:bar, :baz] to Statman counter "foo.bar"
      {:ok, pid} = TelemetryMetricsStatman.start_link(metrics: [
            Telemetry.Metrics.counter("foo.bar", event_name: [:bar, :baz])])
      :telemetry.execute([:bar, :baz], %{})
      # Assert that the Statman counter was actually incremented
      assert_called(:statman.incr({:foo, :bar}, 1))

      Process.unlink(pid)
      Process.exit(pid, :kill)
    end
  end
end
