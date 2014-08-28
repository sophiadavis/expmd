defmodule Expmd do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec
    
    {:ok, port} = Application.fetch_env(:expmd, :port)

    children = [
      supervisor(Task.Supervisor, [[name: Expmd.Pool]]),
      worker(Expmd.Node, [[name: Expmd.Node]]),
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
    
  """
  Distribution protocol response and request identifiers.
  """
  @alive_req 120
  @alive_resp 121
  @port_req 122
  @port_resp 119
  @names_req 110
    
  """
  Parse request and send appropriate response.
  The connection is closed after each successful interaction.
  """
  defp serve(socket) do
    case next_message(socket) do
      {:ok, <<@alive_req, port::16, type, protocol, high_version::16, low_version::16,
              nlen::16, name::binary-size(nlen), elen::16, extra::binary-size(elen)>>} ->
        node = %Expmd.Node{port: port, type: type, protocol: protocol, 
                        high_version: high_version, low_version: low_version, 
                        name: name, extra: extra, pid: self()}
        register_and_send_alive_response(name, node, socket)
        
      {:ok, <<@port_req, name::binary>>} ->
        response = port_response(name)
        :gen_tcp.send(socket, response)
        :ok = :gen_tcp.close(socket)
        
      {:ok, <<@names_req>>} -> 
        node_list = Expmd.Node.get_all(Expmd.Node)
        {:ok, my_port} = :inet.port(socket)
        :gen_tcp.send(socket, <<my_port::32>>)
        Enum.each(node_list, fn node -> :gen_tcp.send(socket, "name #{node.name} at port #{node.port}\n") end)
        :ok = :gen_tcp.close(socket)

      {:error, reason} ->
        Logger.info "TCP exited with reason: #{inspect reason}"
    end
  end
  
  """
  Determine length of incoming message and extract request. 
  (Each EPMD request begins with a two-byte integer indicating the total length of the message.)
  """
  defp next_message(socket) do
    case :gen_tcp.recv(socket, 2) do
      {:ok, <<int::16>>} ->
        Logger.debug "Reading message with length: #{int}"
        :gen_tcp.recv(socket, int)
      {:error, _} = error ->
        error
    end
  end
  
  """
  Handle request to contact node with name `name`.
  If such a node is currently registered, the response contains the port where it
    is running and other information.
  Otherwise, an error response is sent.
  """
  defp port_response(name) do
    case Expmd.Node.get(Expmd.Node, name) do
      nil -> 
        Logger.debug "Connect request to #{name} failed."
        <<@port_resp, 1>>
      node -> 
        Logger.debug "Connect request to #{name} on port #{node.port}."
        name_len = byte_size(node.name)
        extra_len = byte_size(node.extra)
        <<@port_resp, 0, node.port::16, node.type, 
          node.protocol, node.high_version::16, node.low_version::16, 
          name_len::16, node.name::binary-size(name_len), extra_len::16, node.extra::binary-size(extra_len)>>
    end
  end
  
  """
  Handle request to register a new node under name `name`.
  If another node is already registered with this name, an error response is sent.
  Otherwise, information about the new node is registered, and a response indicating success is sent.
  """
  defp register_and_send_alive_response(name, node, socket) do
    Logger.debug "Alive request: #{inspect node}, #{inspect self()}"
    
    case Expmd.Node.put(Expmd.Node, name, node) do
      :ok -> 
        :gen_tcp.send(socket, <<@alive_resp, 0, 1::16>>)
        {:error, _reason} = :gen_tcp.recv(socket, 0)
      :error -> 
        :gen_tcp.send(socket, <<@alive_resp, 1, 1::16>>)
        :ok = :gen_tcp.close(socket)
    end
  end
end
