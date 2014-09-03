ExPMD
=====

An implementation of a replacement Erlang Port Mapper Daemon, written in Elixir.  

The EPMD is a tcp server written in C, which ships with Erlang. Its job is to store information about all nodes registered on its network, so when any node wants to find out how to contact another node, it contacts the EPMD up for that information. Requests and responses are sent using a binary protocol. This program supports the following requests, according to the EPMD [distribution protocol](http://www.erlang.org/doc/apps/erts/erl_dist_protocol.html):  

* Alive request  
When a named node starts up for the first time (ex: `Node.start(:foo, :shortnames)` or `iex --sname foo`), the EPMD registers the name, port, and other attributes, responding whether or not registration was successful. This connection remains open until the node finally exits, at which point the EPMD discards information pertaining to this node.   
*  Names request  
Executed when a node requests information about all nodes currently registered with its local EPMD (ex: `:net_adm.names`). The EPMD sends the node a list containing names and ports of all registered nodes.    
* Port request  
Executed when one node wants to locate a second node (ex: `Node.ping :"foo@machine"`). The EPMD responds with the port on which the second node is running.  

## Usage

Make sure the real EPMD is not running locally, then run:

```
mix run --no-halt
```

The ExPMD is now up and running on port 4369.

In order to coordinate between nodes on different machines, make sure the cookies are equal (use `Node.set_cookie` and `Node.get_cookie`). Start each node with the name `name@machine_ip_address`. Then the nodes on different machines can ping each other by executing `Node.ping :"name@other_machine_ip"`. Notice that each EPMD still only knows about the nodes on its local network.
