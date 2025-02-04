defmodule OtelDemoWeb.Router do
  use OtelDemoWeb, :router

  pipeline :api do
    plug OtelDemoWeb.Plugs.RequestTracer
    plug :accepts, ["json"]
  end

  scope "/api", OtelDemoWeb do
    pipe_through :api
    get "/test", TestController, :index
    # resources "/users", UserController, except: [:new, :edit]
  end
end
