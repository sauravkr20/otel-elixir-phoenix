defmodule OtelDemoWeb.UserController do
  use OtelDemoWeb, :controller
  use OtelDemoWeb.Tracer
  require Logger

  @span "list_users_action"
  def index(conn, _params) do
    users = list_users()
    add_event("users_fetched", %{count: length(users)})
    render(conn, :index, users: users)
  end

  @span "database_list_users"
  defp list_users do
    # Database query would auto-trace if Ecto tracer is configured
    users = []
    add_event("db_query_complete", %{table: "users"})
    users
  end
end
