# Project3

**What is working:**: Pastry protocol:
We have implemented the pastry protocol using Actor model. We have implemented the network join and the routing functionalities of the Pastry API. The number of nodes to the network is taken as user input. We have divided the number of nodes into two groups (the first group containing 1024 nodes and the other containing the remaining nodes). We have built the initial network of 1024 nodes first and then each of the remaining nodes joins the existing network using the network join functionality. The number of requests is taken as user input. Each node sends a request per sec to another random node. When all nodes have performed that many requests, the program exits. Then, we calculate the average number of hops.

We can the algorithm on 100, 500, 1000, 2000 nodes with 10 requests. We got the average number of hops as follows:

| ﻿  Nodes     |   Average no. of hops     | 
|--------------|---------------------------|
| 100          | 3.267                     | 
| 500          | 4.1204                    | 
| 1000         | 4.5168                    | 
| 2000         | 5.08815                   |



**What is the largest network you managed to deal with:**

The maximum number of actors against which we could run our Pastry protocol was 10000 nodes.

```
roukna-~/roukna_folder/project3$ ./project3 10000 10
Total number of hops: 654587
Total number of routes: 100000
Average hops per route: 6.54587
** (EXIT from #PID<0.75.0>) shutdown
```
