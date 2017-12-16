defmodule Project3.Pastry do
    use GenServer
        
        @name :master
        @base 4
        
        def startlink(nodeID, noOfNodes) do
          nodename = String.to_atom("node"<>Integer.to_string(nodeID))
          GenServer.start_link(__MODULE__, [nodeID, noOfNodes], name: nodename)
        end
        
        def toBaseString(nodeID, len) do
          baseNodeID = Integer.to_string(nodeID, @base)
          String.pad_leading(baseNodeID, len, "0")
        end
    
        def getSamePrefix(node1, node2, bitPos) do
          if String.first(node1) != String.first(node2) do
            bitPos
          else
            getSamePrefix(String.slice(node1, 1..(String.length(node1)-1)), String.slice(node2, 1..(String.length(node2)-1)), bitPos+1)
          end   
        end
    
        def getNearestNeighbour([neighbor | rest], toID, nearestNode, difference) do
          if(abs(toID - neighbor) < difference) do
            nearestNode = neighbor
            difference = abs(toID-neighbor)
          end
          getNearestNeighbour(rest, toID, nearestNode, difference)
        end
            
        def getNearestNeighbour([], toID, nearestNode, difference) do
          {nearestNode, difference}
        end
        
        def multicastNodes(routing_table, i, j, noOfBits, selfID, noOfBack) do
          if i >= noOfBits or j >= 4 do
            noOfBack
          else
            node = elem(elem(routing_table, i), j)
            if node != -1 do
              noOfBack = noOfBack + 1
              GenServer.cast(String.to_atom("node"<>Integer.to_string(node)), {:update_self, selfID})
            end
            noOfBack = multicastNodes(routing_table, i, j + 1, noOfBits, selfID, noOfBack)
            if j == 0 do
              noOfBack = multicastNodes(routing_table, i + 1, j, noOfBits, selfID, noOfBack)
            end
            noOfBack
          end
        end
    
        def addLeafAndTableEntry(selfID, firstGroup, noOfBits, lesserLeaf, largerLeaf, routing_table) do
          if length(firstGroup) == 0 do
            {lesserLeaf, largerLeaf, routing_table}
          else
            # add to Larger leaf set
            nodeID = List.first(firstGroup)              
            largerLeaf = if (nodeID > selfID && !Enum.member?(largerLeaf, nodeID)) do
              if(length(largerLeaf) < 4) do
                largerLeaf ++ [nodeID]    
              else
                  if (nodeID < Enum.max(largerLeaf)) do
                    largerLeaf = List.delete(largerLeaf, Enum.max(largerLeaf))
                    largerLeaf ++ [nodeID]    
                  else
                    largerLeaf
                  end
              end
            else
              largerLeaf
            end
                
            # add to Lesser leaf
            lesserLeaf = if (!Enum.member?(lesserLeaf, nodeID) && nodeID < selfID ) do
              if(length(lesserLeaf) < 4) do
                lesserLeaf ++ [nodeID]
              else
                if (nodeID > Enum.min(lesserLeaf)) do
                  lesserLeaf = List.delete(lesserLeaf, Enum.min(lesserLeaf))
                  lesserLeaf ++ [nodeID]
                else
                  lesserLeaf
                end
              end
            else
              lesserLeaf
            end
              
            samePref = getSamePrefix(toBaseString(selfID, noOfBits), toBaseString(nodeID, noOfBits), 0) # routing table chk
            nextBit = String.to_integer(String.at(toBaseString(nodeID, noOfBits), samePref))
    
            routing_table = if elem(elem(routing_table, samePref), nextBit) == -1 do
              row = elem(routing_table, samePref)
              updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, nodeID)
              Tuple.insert_at(Tuple.delete_at(routing_table, samePref), samePref, updatedRow)
            else
              routing_table
            end
            addLeafAndTableEntry(selfID, List.delete_at(firstGroup, 0), noOfBits, lesserLeaf, largerLeaf, routing_table)
            end
          end
        
        def sendReq([head | tail], selfID, nodeIDSpace) do
          Process.sleep(1000)
          listOfNeighbours = Enum.to_list(0..nodeIDSpace-1)
              dest = Enum.random(List.delete(listOfNeighbours, selfID))
              GenServer.cast(String.to_atom("node"<>Integer.to_string(selfID)), {:route, "Route", selfID, dest, 0})
              sendReq(tail, selfID, nodeIDSpace)
        end
        
        def sendReq([], selfID, nodeIDSpace) do
          {:ok}
        end
        
        def init([nodeID, noOfNodes]) do
          noOfBits = round(Float.ceil(:math.log(noOfNodes)/:math.log(@base)))
          rowTab = Tuple.duplicate(-1, @base)
          routing_table = Tuple.duplicate(rowTab, noOfBits)
          noOfBack = 0
              
          {:ok, {nodeID, noOfNodes, [], [], routing_table, noOfBack}}
        end
    
        def handle_cast({:create_network, firstGroup}, state) do
            {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack} = state
            noOfBits = round(Float.ceil(:math.log(noOfNodes)/:math.log(@base)))
            firstGroup = List.delete(firstGroup, selfID)
            {lesserLeaf, largerLeaf, routing_table} = addLeafAndTableEntry(selfID, firstGroup, noOfBits, lesserLeaf, largerLeaf, routing_table)
      
            for i <- 0..(noOfBits-1) do
              nextBit = String.to_integer(String.at(toBaseString(selfID, noOfBits), i))
              row = elem(routing_table, i)
              updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, selfID)
              Tuple.insert_at(Tuple.delete_at(routing_table, i), i, updatedRow)
            end
      
            GenServer.cast(:global.whereis_name(@name), :join_finish)
            {:noreply, {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack}}
        end
        
        def handle_cast({:route, message, fromId, toID, hops}, state) do
          {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack} = state
          noOfBits = round(Float.ceil(:math.log(noOfNodes)/:math.log(@base)))
          nodeIDSpace = round(Float.ceil(:math.pow(@base, noOfBits)))
        
          if message == "Join" do
            samePref = getSamePrefix(toBaseString(selfID, noOfBits), toBaseString(toID, noOfBits), 0)
            nextBit = String.to_integer(String.at(toBaseString(toID, noOfBits), samePref))
            
          if(hops == 0 && samePref > 0) do
            for i <- 0..(samePref-1) do
              GenServer.cast(String.to_atom("node"<>Integer.to_string(toID)), {:update_table_row, i, elem(routing_table,i)})
            end
          end
          GenServer.cast(String.to_atom("node"<>Integer.to_string(toID)), {:update_table_row, samePref, elem(routing_table, samePref)})
          
          cond do
            (length(lesserLeaf)>0 && toID >= Enum.min(lesserLeaf) && toID <= selfID) || (length(largerLeaf)>0 && toID <= Enum.max(largerLeaf) && toID >= selfID) ->        
              difference=nodeIDSpace + 10
              nearestNode=-1
              {nearestNode,difference} = if(toID < selfID) do
                getNearestNeighbour(lesserLeaf, toID, nearestNode, difference)
              else 
                getNearestNeighbour(largerLeaf, toID, nearestNode, difference)
              end
            
              if(abs(toID - selfID) > difference) do
                GenServer.cast(String.to_atom("node"<>Integer.to_string(nearestNode)), {:route,message,fromId,toID,hops+1}) 
              else #I am the nearestNode
                allLeaf = [selfID] ++ lesserLeaf ++ largerLeaf # check syntax
                GenServer.cast(String.to_atom("node"<>Integer.to_string(toID)), {:add_leaf,allLeaf})
              end 
            #cond else if       
            length(lesserLeaf)<4 && length(lesserLeaf)>0 && toID < Enum.min(lesserLeaf) ->
              GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,message,fromId,toID,hops+1})
            length(largerLeaf)<4 && length(largerLeaf)>0 && toID > Enum.max(largerLeaf) ->
              GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.max(largerLeaf))), {:route,message,fromId,toID,hops+1})
            (length(lesserLeaf)==0 && toID<selfID) || (length(largerLeaf)==0 && toID>selfID) -> #I am the nearestNode
              allLeaf = [selfID] ++ lesserLeaf ++ largerLeaf # check syntax
              GenServer.cast(String.to_atom("node"<>Integer.to_string(toID)), {:add_leaf,allLeaf})
            elem(elem(routing_table, samePref), nextBit) != -1 ->
              GenServer.cast(String.to_atom("node"<>Integer.to_string(elem(elem(routing_table, samePref), nextBit))), {:route,message,fromId,toID,hops+1})
            toID > selfID ->
              GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.max(largerLeaf))), {:route,message,fromId,toID,hops+1})
            toID < selfID ->
              GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,message,fromId,toID,hops+1})
            true ->
              IO.puts("Not possible to route")
            end
             else
                # message == "Route"
                if selfID == toID do
                  GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})# to be implemented
                else 
                  samePref = getSamePrefix(toBaseString(selfID, noOfBits), toBaseString(toID, noOfBits), 0)
                  nextBit = String.to_integer(String.at(toBaseString(toID, noOfBits), samePref))
                
                cond do
                  #first condition
                  (length(lesserLeaf)>0 && toID >= Enum.min(lesserLeaf) && toID < selfID) || (length(largerLeaf)>0 && toID <= Enum.max(largerLeaf) && toID > selfID) ->
                    difference=nodeIDSpace + 10
                    nearestNode=-1
                    {nearestNode,difference} = if(toID < selfID) do
                      getNearestNeighbour(lesserLeaf, toID, nearestNode, difference)
                    else 
                      getNearestNeighbour(largerLeaf, toID, nearestNode, difference)
                    end
        
                    if(abs(toID - selfID) > difference) do
                      GenServer.cast(String.to_atom("node"<>Integer.to_string(nearestNode)), {:route,"Route",fromId,toID,hops+1})
                    else #I am the nearestNode
                      GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})
                    end                          
                  length(lesserLeaf)<4 && length(lesserLeaf)>0 && toID < Enum.min(lesserLeaf) ->
                    GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,"Route",fromId,toID,hops+1})
                  length(largerLeaf)<4 && length(largerLeaf)>0 && toID > Enum.max(largerLeaf) ->
                    GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.max(largerLeaf))), {:route,"Route",fromId,toID,hops+1})
                  (length(lesserLeaf)==0 && toID<selfID) || (length(largerLeaf)==0 && toID>selfID) -> #I am the nearestNode
                    GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})
                    elem(elem(routing_table, samePref), nextBit) != -1 ->
                    GenServer.cast(String.to_atom("node"<>Integer.to_string(elem(elem(routing_table, samePref), nextBit))), {:route,"Route",fromId,toID,hops+1})
                  toID > selfID ->
                    GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.max(largerLeaf))), {:route,"Route",fromId,toID,hops+1})
                  toID < selfID ->
                    GenServer.cast(String.to_atom("node"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,"Route",fromId,toID,hops+1})
                  true ->
                    IO.puts("Impossible")
                  end  #end of cond       
                end #end of if selfId = toID
              end  #end of cond
              {:noreply, {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack}}
            end
    
            def handle_cast({:begin_route, numRequests}, state) do
              {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack} = state
              noOfBits = round(Float.ceil(:math.log(noOfNodes)/:math.log(@base)))
              nodeIDSpace = round(Float.ceil(:math.pow(@base, noOfBits)))
                
              sendReq(Enum.to_list(1..numRequests), selfID, nodeIDSpace)
              {:noreply, {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack}}
            end
            
            #Add row
            def handle_cast({:update_table_row,rowNum,newRow}, state) do 
              {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack} = state
              routing_table =  Tuple.insert_at(Tuple.delete_at(routing_table, rowNum), rowNum, newRow)  
              {:noreply, {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack}}
            end    
        
            def handle_cast({:add_leaf, allLeaf}, state) do
              {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack} = state
              noOfBits = round(Float.ceil(:math.log(noOfNodes)/:math.log(@base)))
              {lesserLeaf, largerLeaf, routing_table} = addLeafAndTableEntry(selfID, allLeaf, noOfBits, lesserLeaf, largerLeaf, routing_table)
              
              for i <- lesserLeaf do
                    GenServer.cast(String.to_atom("node"<>Integer.to_string(i)), {:update_self, selfID})
              end
              for i <- largerLeaf do
                    GenServer.cast(String.to_atom("node"<>Integer.to_string(i)), {:update_self, selfID})
              end
              
              noOfBack = noOfBack + length(lesserLeaf) + length(largerLeaf)
              noOfBack = multicastNodes(routing_table, 0, 0, noOfBits, selfID, noOfBack)
              for i <- 0..(noOfBits-1) do
                for j <- 0..3 do
                  row = elem(routing_table, i)
                  updatedRow = Tuple.insert_at(Tuple.delete_at(row, j), j, selfID)
                  Tuple.insert_at(Tuple.delete_at(routing_table, i), i, updatedRow)
                end
              end
              {:noreply, {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack}}
            end
        
            def handle_cast(:acknowledge, state) do
              {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack} = state
              noOfBack = noOfBack - 1
              if(noOfBack == 0) do
                GenServer.cast(:global.whereis_name(@name), :join_finish)
              end
              {:noreply, {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack}}
            end
        
            
            def handle_cast({:update_self, newNode}, state) do
              {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack} = state
              noOfBits = round(Float.ceil(:math.log(noOfNodes)/:math.log(@base)))
              {lesserLeaf, largerLeaf, routing_table} = addLeafAndTableEntry(selfID, [newNode], noOfBits, lesserLeaf, largerLeaf, routing_table)
    
              GenServer.cast(String.to_atom("node"<>Integer.to_string(newNode)), :acknowledge)
              {:noreply, {selfID, noOfNodes, lesserLeaf, largerLeaf, routing_table, noOfBack}}
            end
        end