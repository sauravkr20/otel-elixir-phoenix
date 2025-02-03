defmodule OtelDemoWeb.TestController do
  use OtelDemoWeb, :controller
  use OtelDemoWeb.Tracer

  @span "test_action"
  def index(conn, _params) do
    text(conn, "Test endpoint")
  end
end
