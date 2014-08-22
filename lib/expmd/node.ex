defmodule Expmd.Node do
  defstruct [port: 0, type: 77, protocol: 0, high_version: 5, low_version: 5, name: "", extra: ""] 
  
  @name __MODULE__
  def start_link do
    Agent.start_link(fn -> HashDict.new end, [name: @name])
  end
  
  def put(name, node) do
    Agent.update(Expmd.Node, &HashDict.put(&1, name, node))
  end
  
  def get(name) do
    Agent.get(Expmd.Node, &HashDict.get(&1, name))
  end
  
  def get_all do
    Agent.get(Expmd.Node, &HashDict.values(&1))
  end
end