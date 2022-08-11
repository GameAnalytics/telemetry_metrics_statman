defmodule TelemetryMetricsStatman do
  @moduledoc """
  `Telemetry.Metrics` reporter that uses Statman as a middleman for metrics aggregation.

  To start using statman reporter, start the reporter under a
  supervision tree with a provided list of metrics, that have to be
  reported:

      import Telemetry.Metrics

      TelemetryMetricsStatman.start_link(
        metrics: [
          counter("phoenix.endpoint.count"),
          summary("phoenix.endpoint.duration"),
          sum("customers.provisioned.count")
        ]
      )

  Telemetry metrics are mapped to the internal statman metric types as follows:

  - `counter` -> `counter`
  - `sum` -> `gauge` (metric is incremented every when it's reported)
  - `last_value` -> `gauge`
  - `summary` -> `histogram`
  - `distribution` -> `histogram`
  """

  use GenServer

  alias Telemetry.Metrics


  def start_link(options) do
    options[:metrics] ||
      raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"

    GenServer.start_link(__MODULE__, options)
  end


  @impl true
  def init(options) do
    Process.flag(:trap_exit, true)
    handler_ids = attach(options[:metrics])

    {:ok, handler_ids}
  end


  @impl true
  def terminate(_, handler_ids),
    do: detach_handlers(handler_ids)

  def handle_event(_event, measurements, metadata, %{metrics: metrics}) do
    for metric <- metrics do
      if value = keep?(metric, metadata) && find_measurement(metric, measurements) do
        key = metric_key(metric, metric.tags, metadata)
        report(metric, key, value)
      end
    end
  end


  defp report(metric, key, value) when is_float(value) do
    report(metric, key, round(value))
  end

  defp report(%Metrics.Counter{}, key, _value),
  # As per documentation of Telemetry.Metrics.counter,
  # ignore measurement and always increment by one.
    do: :statman.incr(key, 1)

  defp report(%Metrics.Sum{}, key, value),
    do: :statman_gauge.incr(key, value)

  defp report(%Metrics.LastValue{}, key, value),
    do: :statman.set_gauge(key, value)

  defp report(%Metrics.Summary{}, key, value),
    do: :statman_histogram.record_value(key, :statman_histogram.bin(value))

  defp report(%Metrics.Distribution{}, key, value),
    do: :statman_histogram.record_value(key, value)


  defp metric_key(metric, [] = _tags, _metadata),
    do: metric_name(metric)

  defp metric_key(metric, tags, metadata) do
    tag_values = metric.tag_values.(metadata)

    categories =
      tags
      |> Enum.map(&Map.fetch!(tag_values, &1))
      |> List.to_tuple

    {metric_name(metric), categories}
  end


  defp metric_name(metric) do
    case metric.reporter_options[:report_as] do
      nil ->
        List.to_tuple(metric.name)

      name ->
        name
    end
  end


  defp keep?(%{keep: nil}, _metadata), do: true
  defp keep?(%{keep: keep}, metadata), do: keep.(metadata)


  defp find_measurement(%Metrics.Counter{} = metric, measurements) do
    case extract_measurement(metric, measurements) do
      nil ->
        1

      value ->
        value
    end
  end


  defp find_measurement(metric, measurements),
    do: extract_measurement(metric, measurements)


  defp extract_measurement(metric, measurements) do
    case metric.measurement do
      fun when is_function(fun, 1) ->
        fun.(measurements)

      key ->
        measurements[key]
    end
  end


  defp attach(metrics) do
    metrics_by_event = Enum.group_by(metrics, & &1.event_name)
    event_handler = &__MODULE__.handle_event/4

    for {event_name, event_metrics} <- metrics_by_event do
      id = handler_id(event_name)
      :telemetry.attach(id, event_name, event_handler, %{metrics: event_metrics})

      id
    end
  end


  defp detach_handlers(handler_ids) do
    for handler_id <- handler_ids,
        do: :telemetry.detach(handler_id)
  end


  defp handler_id(event_name), do: {__MODULE__, event_name, self()}
end
