defmodule Project3 do
  use GenServer

  @name :master
  @base 4
  @first_group 1024

  def start_link(noOfNodes, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops) do
    GenServer.start_link(__MODULE__, [noOfNodes, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops])
  end

  def init([noOfNodes, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops]) do
      {:ok, {noOfNodes, [], noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops}}
  end
  @doc """
  """   
  def handle_cast(:start, state) do
    {noOfNodes, _, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops} = state
    
    noOfBits = round(Float.ceil(:math.log(noOfNodes)/:math.log(@base)))
    nodeIDSpace = round(Float.ceil(:math.pow(@base, noOfBits)))
    countFirstGroup = if (noOfNodes <=  @first_group) do noOfNodes else  @first_group end
    
    randomList = Enum.shuffle(Enum.to_list(0..(nodeIDSpace-1)))
    firstGroup = Enum.slice(randomList, 0..(countFirstGroup-1))

    list_pid = for nodeID <- firstGroup do
      {_, pid} = Project3.Pastry.startlink(nodeID, noOfNodes)
      pid
    end 

    # Build network
    for pid <- list_pid do
      GenServer.cast(pid, {:create_network, firstGroup})
    end

    {:noreply, {noOfNodes, randomList, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops}}
  end

  def handle_cast(:join_finish, state) do
    {noOfNodes, randomList, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops} = state
    countFirstGroup = if (noOfNodes <=  @first_group) do noOfNodes else  @first_group end
    noOfNodesJoined = noOfNodesJoined + 1
    
    if(noOfNodesJoined >= countFirstGroup) do
      if(noOfNodesJoined >= noOfNodes) do
        GenServer.cast(:global.whereis_name(@name), :begin_route)
      else
        GenServer.cast(:global.whereis_name(@name), :join)
      end
    end

    {:noreply, {noOfNodes, randomList, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops}}
  end

    def handle_cast({:route_finish, hops}, state) do
    {noOfNodes, randomList, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops} = state
    
    noOfRoutedNodes = noOfRoutedNodes + 1
    noOfHops = noOfHops + hops
    if (noOfRoutedNodes >= noOfNodes * noOfRequests) do
      # Display results
      IO.puts "Total number of hops: #{noOfHops}"
      IO.puts "Total number of routes: #{noOfRoutedNodes}"
      IO.puts "Average hops per route: #{noOfHops/noOfRoutedNodes}"
      
      Process.exit(self(), :shutdown)
    end
    {:noreply, {noOfNodes, randomList, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops}}
  end

  def handle_cast(:begin_route, state) do
    {_, randomList, noOfRequests, _, _, _} = state
    
    for node <- randomList do
        GenServer.cast(String.to_atom("node"<>Integer.to_string(node)), {:begin_route, noOfRequests})
    end
    {:noreply, state}
  end

    def handle_cast(:join, state) do
    {noOfNodes, randomList, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops} = state
    startID = Enum.at(randomList, Enum.random(0..(noOfNodesJoined-1)))
    Project3.Pastry.startlink(Enum.at(randomList, noOfNodesJoined), noOfNodes)
    GenServer.cast(String.to_atom("node"<>Integer.to_string(startID)), {:route, "Join", startID, Enum.at(randomList, noOfNodesJoined), 0})
    {:noreply, {noOfNodes, randomList, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops}}
  end

  def main(args) do
    [noOfNodes, noOfRequests] = args
    noOfRoutedNodes = 0
    noOfNodesJoined = 0
    noOfHops = 0

    noOfNodes = String.to_integer(noOfNodes)
    noOfRequests = String.to_integer(noOfRequests)

    {:ok, master_pid} = start_link(noOfNodes, noOfRequests, noOfNodesJoined, noOfRoutedNodes, noOfHops)
    :global.register_name(@name, master_pid)
    :global.sync()
    GenServer.cast(:global.whereis_name(@name), :start)
    
    :timer.sleep(:infinity)
  end
end