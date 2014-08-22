defmodule Expmd do
  use Application

  require Logger
  

  def start(_type, _args) do
    import Supervisor.Spec
    
    {:ok, port} = Application.fetch_env(:expmd, :port)

    children = [
      # Task.Supervisor.start_link([name: Expmd.Pool])
      supervisor(Task.Supervisor, [[name: Expmd.Pool]]),
      # Expmd.Node.start_link
      worker(Expmd.Node, []),
      # Task.start_link(Expmd, :accept, [port])
      worker(Task, [Expmd, :accept, [port]])
    ]

    opts = [strategy: :one_for_all, name: Expmd.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port,
                      [:binary, packet: 0, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}, my pid #{inspect self()}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.Supervisor.start_child(Expmd.Pool, fn -> serve(client) end)
    loop_acceptor(socket)
  end

  @alive_req 120
  @alive_resp 121
  @port_req 122
  @port_resp 119

  defp serve(socket) do
    case next_message(socket) do
      {:ok, <<@alive_req, port::16, type, protocol, high_version::16, low_version::16,
              nlen::16, name::binary-size(nlen), elen::16, extra::binary-size(elen)>>} ->
        
        node = %Expmd.Node{port: port, type: type, protocol: protocol, 
                            high_version: high_version, low_version: low_version, 
                            name: name, extra: extra}
          Expmd.Node.put(name, node)
          Logger.debug "Alive request: #{inspect node}"
          :gen_tcp.send(socket, <<@alive_resp, 0, 1::16>>)
          serve(socket)
      {:ok, <<@port_req, name::binary>>} ->
        :gen_tcp.send(socket, connect_response(name))
        Port.close(socket)
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
  
  defp connect_response(name) do
    Logger.debug "Connect request to: #{name}"
    case Agent.get(Expmd.Node, &HashDict.get(&1, name)) do
      nil -> <<@port_resp, 1>>
      node -> 
        Logger.info inspect node
        Logger.info inspect node.port
        name_len = byte_size(node.name)
        extra_len = byte_size(node.extra)
        <<@port_resp, 0, node.port::16, node.type, 
          node.protocol, node.high_version::16, node.low_version::16, 
          name_len::16, node.name::binary-size(name_len), extra_len::16, node.extra::binary-size(extra_len)>>
    end
  end
end
