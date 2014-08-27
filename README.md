ExPMD
=====

An implementation of the Erlang Port Mapper Daemon in Elixir.  

The following requests are supported according to the EPMD [distribution protocol](http://www.erlang.org/doc/apps/erts/erl_dist_protocol.html):  

* Alive request  
When a named node starts up for the first time (ex: ```Node.start(:foo, :shortnames)``` or ```iex --sname foo```), it registers its name, port, and other attributes with the ExPMD. The ExPMD's response indicates whether registration was successful.   
*  Names request  
Executed when a registered node requests information about all nodes currently registered with the ExPMD (ex: ```:net_adm.names```). The ExPMD sends this node names and ports of all registered nodes.    
* Connect request  
Executed when a node attempts to connect to another node (ex: ```Node.ping :"foo@machine"``).  

When a node exits, the ExPMD discards information pertaining to this node.

-----------  

To use:  
Make sure the real EPMD is not running locally, and run:  
```
mix run --no-halt
```  
The ExPMD is now up and running on port 4369.

In order to coordinate between nodes on different machines...
