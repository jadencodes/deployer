defmodule SampleWebapp.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # start cowboy server as child to supervise
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: SampleWebapp.Endpoint,
        options: [port: 80]
      )
    ]

    opts = [strategy: :one_for_one, name: SampleWebapp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp escript do
    [main_module: ExampleApp.CLI]
  end
end
