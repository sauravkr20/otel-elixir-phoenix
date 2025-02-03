defmodule OtelDemoWeb.Plugs.RequestTracer do
  @behaviour Plug
  require OpenTelemetry.Tracer
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Clear any existing span context at the start of request
    Process.delete(:otel_current_span)

    url_path = "#{conn.scheme}://#{conn.host}#{conn.request_path}"
    operation_name = "#{conn.method} #{url_path}"
    Logger.info("Starting request trace for #{operation_name}")

    OpenTelemetry.Tracer.with_span operation_name, %{attributes: %{
      "http.method" => conn.method,
      "http.scheme" => conn.scheme,
      "http.path" => conn.request_path,
      "http.host" => conn.host,
      "http.url" => url_path,
      "http.target" => conn.request_path,
      "http.flavor" => "1.1",
      "http.user_agent" => get_req_header(conn, "user-agent") |> List.first()
    }} do
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()
      Process.put(:otel_current_span, span_ctx)

      conn = register_before_send(conn, fn conn ->
        current_span = Process.get(:otel_current_span)
        if current_span do
          OpenTelemetry.Span.set_attributes(current_span, %{
            "http.status_code" => conn.status,
            "http.response_content_length" => get_resp_header(conn, "content-length") |> List.first()
          })
        end

        Logger.info("Completing request trace for #{operation_name}")
        Process.delete(:otel_current_span)
        conn
      end)

      conn
    end
  end
end
