defmodule Expmd.Node do
  use GenServer
  require Logger
  
  @doc """ 
  The fields necessary to register a named node.
  """
  defstruct [port: 0, type: 77, protocol: 0, high_version: 5, low_version: 5, 
             name: "", extra: "", pid: nil, ref: nil] 
  
  def start_link(opts \\ []) do
    Logger.info "Inside GenServer, opts are #{inspect opts}"
    GenServer.start_link(__MODULE__, :ok, opts)
  end
  
  @doc """ 
  Registers a node under `name` if no active node with this name is
    currently registered.
  """
  def put(server, name, node) do
    GenServer.call(server, {:put, name, node})
  end
  
  @doc """ 
  Returns the information about the node registered under `name`
  """
  def get(server, name) do
    GenServer.call(server, {:get, name})
  end
  
  @doc """ 
  Returns a list of all currently registered nodes.
  """
  def get_all(server) do
    GenServer.call(server, :getall)
  end
  
  ### server callbacks
  
  def init(:ok) do
    {:ok, HashDict.new}
  end
  
  def handle_call({:put, name, node}, _from, state) do  
    case HashDict.get(state, name) do
      nil -> 
        ref = Process.monitor(node.pid)
        node = %{node | ref: ref}
        state = HashDict.put(state, name, node)
        {:reply, :ok, state}
      _   -> 
        {:reply, :error, state}
    end
  end
  
  def handle_call({:get, name}, _from, state) do
    {:reply, HashDict.get(state, name), state}
  end
  
  def handle_call(:getall, _from, state) do
    {:reply, HashDict.values(state), state}
  end
  
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {name, _} = Enum.find(state, fn {_, v} -> v.ref == ref end)
    {:noreply, HashDict.delete(state, name)}
  end
end
