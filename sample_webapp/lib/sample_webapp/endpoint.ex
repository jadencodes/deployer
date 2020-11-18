defmodule SampleWebapp.Endpoint do
    @moduledoc """
    Simple endpoint to serve "pong!" to a http request.
    """

    use Plug.Router

    plug(Plug.Logger)
    plug(:match)
    plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
    # responsible for dispatching responses
    plug(:dispatch)

    # A simple route to test that the server is up
    get "/" do
        send_resp(conn, 200, "pong!")
    end

    # catch all
    match _ do
        send_resp(conn, 404, "Nothing here! (404) :(")
    end
end