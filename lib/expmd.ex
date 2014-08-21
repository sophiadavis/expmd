defmodule Expmd do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec

    {:ok, port} = Application.fetch_env(:expmd, :port)

    children = [
      supervisor(Task.Supervisor, [[name: Expmd.Pool]]),
      worker(Task, [Expmd, :accept, [port]])
    ]

    opts = [strategy: :one_for_one, name: Expmd.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port,
                      [:binary, packet: 0, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.Supervisor.start_child(Expmd.Pool, fn -> serve(client) end)
    loop_acceptor(socket)
  end

  @alive_req 120
  @alive_resp 121

  defp serve(socket) do
    case next_message(socket) do
      {:ok, <<@alive_req, port::16, node_type, protocol, high_version::16, low_version::16,
              nlen::16, node::binary-size(nlen), elen::16, extra::binary-size(elen)>> = msg} ->
        Logger.debug "Alive request: #{node} - #{port}"
        :gen_tcp.send(socket, <<@alive_resp, 0, 1::16>>)
        serve(socket)
      {:error, reason} ->
        Logger.info "TCP exited with reason: #{inspect reason}"
    end
  end

  defp next_message(socket) do
    case :gen_tcp.recv(socket, 2) do
      {:ok, <<int::16>>} ->
        Logger.debug "Reading message with length: #{int}"
        :gen_tcp.recv(socket, int)
      {:error, _} = error ->
        error
    end
  end
end
