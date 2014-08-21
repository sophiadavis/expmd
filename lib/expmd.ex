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
                      [:binary, packet: :line, active: false, reuseaddr: true])
    IO.puts "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.Supervisor.start_child(Expmd.Pool, fn -> serve(client) end)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    case read_line(socket) do
      {:ok, msg} ->
        write_line(socket, msg)
        serve(socket)
      {:error, reason} -> 
        Logger.info "TCP exited with reason: #{inspect reason}"
    end
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, msg) do
    :gen_tcp.send(socket, msg)
  end
end
